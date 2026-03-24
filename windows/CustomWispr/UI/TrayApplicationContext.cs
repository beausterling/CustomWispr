using System;
using System.Drawing;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Forms;
using CustomWispr.Core;

namespace CustomWispr.UI;

internal class TrayApplicationContext : ApplicationContext
{
    private readonly NotifyIcon _trayIcon;
    private readonly GlobalKeyboardHook _keyHook = new();
    private readonly AudioRecorder _recorder = new();
    private readonly WhisperService _whisper = new();
    private readonly AICleanupService _cleanup = new();
    private readonly TextInjector _injector = new();
    private readonly OverlayForm _overlay = new();

    private bool _isRecording;
    private bool _isProcessing;
    private CancellationTokenSource? _processingCts;
    private System.Windows.Forms.Timer? _maxRecordingTimer;

    private const int MaxRecordingMs = 300_000;    // 5 minutes
    private const int MaxProcessingMs = 150_000;   // 150 seconds

    public TrayApplicationContext()
    {
        Logger.Log("App launched");
        AudioRecorder.CleanupStaleFiles();

        // Create tray icon
        _trayIcon = new NotifyIcon
        {
            Icon = CreateTrayIcon(),
            Text = "CustomWispr",
            Visible = true,
            ContextMenuStrip = CreateContextMenu()
        };

        // Load hotkey settings
        _keyHook.HotkeyKey = SettingsManager.Shared.HotkeyKey;
        _keyHook.HotkeyModifiers = SettingsManager.Shared.HotkeyModifiers;

        // Check onboarding
        if (!SettingsManager.Shared.HasCompletedOnboarding || !Config.HasAPIKey)
        {
            Logger.Log("First launch, showing welcome window");
            var welcome = new WelcomeForm();
            if (welcome.ShowDialog() == DialogResult.OK)
            {
                SettingsManager.Shared.HasCompletedOnboarding = true;
                SettingsManager.Shared.Save();
            }
        }

        // Start key monitor
        _keyHook.OnHotkeyDown += HandleHotkeyDown;
        _keyHook.OnHotkeyUp += HandleHotkeyUp;

        if (_keyHook.Start())
            Logger.Log("Key monitor started successfully");
        else
            Logger.Log("ERROR: Failed to start key monitor");

        // Check for updates after a short delay
        Task.Delay(3000).ContinueWith(_ =>
        {
            try { UpdateChecker.CheckForUpdates().Wait(); } catch { }
        });
    }

    private static Icon CreateTrayIcon()
    {
        // Create a simple microphone icon programmatically
        var bmp = new Bitmap(16, 16);
        using (var g = Graphics.FromImage(bmp))
        {
            g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
            g.Clear(Color.Transparent);

            using var pen = new Pen(Color.White, 1.5f);
            // Mic head (circle)
            g.DrawEllipse(pen, 4, 1, 8, 8);
            // Stem
            g.DrawLine(pen, 8, 9, 8, 12);
            // Base
            g.DrawLine(pen, 5, 12, 11, 12);
        }
        return Icon.FromHandle(bmp.GetHicon());
    }

    private ContextMenuStrip CreateContextMenu()
    {
        var menu = new ContextMenuStrip();
        menu.Items.Add("CustomWispr").Enabled = false;
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Settings...", null, (_, _) => OpenSettings());
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Quit", null, (_, _) => Quit());
        return menu;
    }

    private void OpenSettings()
    {
        var settings = new SettingsForm();
        settings.ShowDialog();
        // Reload hotkey after settings change
        _keyHook.HotkeyKey = SettingsManager.Shared.HotkeyKey;
        _keyHook.HotkeyModifiers = SettingsManager.Shared.HotkeyModifiers;
    }

    private void Quit()
    {
        _keyHook.Dispose();
        _recorder.Dispose();
        _trayIcon.Visible = false;
        _trayIcon.Dispose();
        Application.Exit();
    }

    private void HandleHotkeyDown()
    {
        if (!Config.HasAPIKey)
        {
            Logger.Log("Ignoring hotkey (no API key configured)");
            return;
        }

        // If processing is stuck, cancel it so user can start fresh
        if (_isProcessing)
        {
            Logger.Log("Cancelling stuck processing task");
            _processingCts?.Cancel();
            _processingCts = null;
            _isProcessing = false;
            _overlay.HideOverlay();
            _recorder.Cleanup();
        }

        if (_isRecording)
        {
            Logger.Log("Ignoring hotkey (already recording)");
            return;
        }

        _isRecording = true;
        _overlay.ShowOverlay("Listening...");

        try
        {
            _recorder.StartRecording();

            _maxRecordingTimer = new System.Windows.Forms.Timer { Interval = MaxRecordingMs };
            _maxRecordingTimer.Tick += (_, _) =>
            {
                Logger.Log("Max recording duration reached (5 min), auto-stopping");
                _maxRecordingTimer?.Stop();
                HandleHotkeyUp();
            };
            _maxRecordingTimer.Start();
        }
        catch (Exception ex)
        {
            Logger.Log($"ERROR: Failed to start recording: {ex.Message}");
            _isRecording = false;
            _overlay.HideOverlay();
        }
    }

    private void HandleHotkeyUp()
    {
        if (!_isRecording) return;
        _isRecording = false;
        _isProcessing = true;
        _maxRecordingTimer?.Stop();
        _maxRecordingTimer?.Dispose();
        _maxRecordingTimer = null;

        var audioPath = _recorder.StopRecording();
        if (string.IsNullOrEmpty(audioPath))
        {
            Logger.Log("ERROR: No audio file after stopping recording");
            _isProcessing = false;
            _overlay.HideOverlay();
            return;
        }

        _overlay.ShowOverlay("Transcribing...");
        Logger.Log("Recording stopped, processing...");

        _processingCts = new CancellationTokenSource(MaxProcessingMs);
        var ct = _processingCts.Token;

        Task.Run(async () =>
        {
            try
            {
                // Step 1: Transcribe
                var rawText = await _whisper.TranscribeAsync(audioPath, ct);
                Logger.Log($"Transcribed: {rawText[..Math.Min(100, rawText.Length)]}...");

                if (string.IsNullOrWhiteSpace(rawText))
                {
                    Logger.Log("Empty transcription, skipping");
                    return;
                }

                // Step 2: Clean up with AI
                _overlay.BeginInvoke(() => _overlay.ShowOverlay("Cleaning up..."));
                var cleanedText = await _cleanup.CleanupAsync(rawText, ct);
                Logger.Log($"Cleaned: {cleanedText[..Math.Min(100, cleanedText.Length)]}...");

                // Step 3: Inject into active text field
                _injector.Inject(cleanedText);
                Logger.Log("Text injected successfully");
            }
            catch (OperationCanceledException)
            {
                Logger.Log("Processing was cancelled");
            }
            catch (Exception ex)
            {
                Logger.Log($"ERROR: Processing failed: {ex.Message}");
            }
            finally
            {
                _overlay.BeginInvoke(() =>
                {
                    _isProcessing = false;
                    _processingCts = null;
                    _overlay.HideOverlay();
                    _recorder.Cleanup();
                });
            }
        }, ct);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _keyHook.Dispose();
            _recorder.Dispose();
            _trayIcon.Dispose();
        }
        base.Dispose(disposing);
    }
}
