using System;
using System.Drawing;
using System.Windows.Forms;
using CustomWispr.Core;

namespace CustomWispr.UI;

internal class WelcomeForm : Form
{
    private static readonly Color BgColor = Color.FromArgb(14, 14, 16);
    private static readonly Color TextColor = Color.FromArgb(232, 230, 227);
    private static readonly Color MutedColor = Color.FromArgb(148, 146, 157);
    private static readonly Color AccentColor = Color.FromArgb(245, 158, 11);
    private static readonly Color GreenColor = Color.FromArgb(34, 197, 94);

    private int _currentStep;
    private readonly Panel _contentPanel;
    private readonly Panel _dotsPanel;
    private string _realApiKey = "";

    private const int TotalSteps = 4;

    public WelcomeForm()
    {
        Text = "Welcome to CustomWispr";
        Size = new Size(500, 450);
        StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox = false;
        BackColor = BgColor;
        ForeColor = TextColor;

        // Dark title bar
        var value = 1;
        NativeMethods.DwmSetWindowAttribute(Handle,
            NativeMethods.DWMWA_USE_IMMERSIVE_DARK_MODE, ref value, sizeof(int));

        _contentPanel = new Panel
        {
            Location = new Point(0, 0),
            Size = new Size(500, 390),
        };
        Controls.Add(_contentPanel);

        _dotsPanel = new Panel
        {
            Location = new Point(0, 390),
            Size = new Size(500, 40),
            BackColor = BgColor
        };
        Controls.Add(_dotsPanel);

        ShowStep(0);
    }

    private void ShowStep(int step)
    {
        _currentStep = step;
        _contentPanel.Controls.Clear();
        UpdateDots();

        switch (step)
        {
            case 0: ShowWelcomeStep(); break;
            case 1: ShowHotkeyStep(); break;
            case 2: ShowApiKeyStep(); break;
            case 3: ShowFinishStep(); break;
        }
    }

    private void UpdateDots()
    {
        _dotsPanel.Controls.Clear();
        var totalWidth = TotalSteps * 12 + (TotalSteps - 1) * 8;
        var startX = (500 - totalWidth) / 2;

        for (int i = 0; i < TotalSteps; i++)
        {
            var dot = new Panel
            {
                Location = new Point(startX + i * 20, 12),
                Size = new Size(12, 12),
                BackColor = i == _currentStep ? AccentColor : Color.FromArgb(60, 60, 70)
            };
            dot.Paint += (s, e) =>
            {
                var p = (Panel)s!;
                e.Graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
                using var brush = new SolidBrush(p.BackColor);
                e.Graphics.FillEllipse(brush, 0, 0, 11, 11);
            };
            dot.BackColor = BgColor; // Background behind the circle
            dot.Tag = i == _currentStep ? AccentColor : Color.FromArgb(60, 60, 70);
            dot.Paint += (s, e) =>
            {
                var p = (Panel)s!;
                e.Graphics.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
                using var brush = new SolidBrush((Color)p.Tag);
                e.Graphics.FillEllipse(brush, 0, 0, 11, 11);
            };
            _dotsPanel.Controls.Add(dot);
        }
    }

    // --- Step 0: Welcome ---
    private void ShowWelcomeStep()
    {
        var title = MakeLabel("Welcome to CustomWispr", 0, 60, 16, true);
        title.TextAlign = ContentAlignment.MiddleCenter;
        title.Size = new Size(500, 30);
        _contentPanel.Controls.Add(title);

        var desc = MakeLabel(
            "Hold a hotkey, speak naturally, release.\n" +
            "Your words appear instantly — cleaned up and formatted.",
            0, 110, 11, false);
        desc.TextAlign = ContentAlignment.MiddleCenter;
        desc.Size = new Size(500, 50);
        desc.ForeColor = MutedColor;
        _contentPanel.Controls.Add(desc);

        var nextBtn = MakeAccentButton("Get Started", 175, 250, 150, 36);
        nextBtn.Click += (_, _) => ShowStep(1);
        _contentPanel.Controls.Add(nextBtn);
    }

    // --- Step 1: Hotkey Info ---
    private void ShowHotkeyStep()
    {
        var title = MakeLabel("Your Hotkey", 0, 60, 16, true);
        title.TextAlign = ContentAlignment.MiddleCenter;
        title.Size = new Size(500, 30);
        _contentPanel.Controls.Add(title);

        var hotkeyStr = "Ctrl + Win";
        var desc = MakeLabel(
            $"CustomWispr uses  {hotkeyStr}  to start recording.\n\n" +
            "Hold the hotkey, speak naturally, then release.\n" +
            "Your transcribed text will appear at your cursor.\n\n" +
            "You can change this hotkey later in Settings.",
            0, 110, 11, false);
        desc.TextAlign = ContentAlignment.MiddleCenter;
        desc.Size = new Size(500, 120);
        desc.ForeColor = MutedColor;
        _contentPanel.Controls.Add(desc);

        var nextBtn = MakeAccentButton("Next", 175, 280, 150, 36);
        nextBtn.Click += (_, _) => ShowStep(2);
        _contentPanel.Controls.Add(nextBtn);
    }

    // --- Step 2: API Key ---
    private void ShowApiKeyStep()
    {
        var title = MakeLabel("OpenAI API Key", 0, 50, 16, true);
        title.TextAlign = ContentAlignment.MiddleCenter;
        title.Size = new Size(500, 30);
        _contentPanel.Controls.Add(title);

        var desc = MakeLabel(
            "CustomWispr uses the OpenAI API for transcription.\n" +
            "You'll need an API key from platform.openai.com",
            0, 90, 10, false);
        desc.TextAlign = ContentAlignment.MiddleCenter;
        desc.Size = new Size(500, 40);
        desc.ForeColor = MutedColor;
        _contentPanel.Controls.Add(desc);

        _realApiKey = Config.ApiKey;
        var apiInput = new TextBox
        {
            Location = new Point(80, 155),
            Size = new Size(340, 28),
            BackColor = Color.FromArgb(30, 30, 34),
            ForeColor = TextColor,
            BorderStyle = BorderStyle.FixedSingle,
            Font = new Font("Segoe UI", 10f),
            Text = string.IsNullOrEmpty(_realApiKey) ? "" : "sk-..."
        };
        _contentPanel.Controls.Add(apiInput);

        var statusLabel = MakeLabel("", 0, 200, 10, false);
        statusLabel.TextAlign = ContentAlignment.MiddleCenter;
        statusLabel.Size = new Size(500, 20);
        _contentPanel.Controls.Add(statusLabel);

        var nextBtn = MakeAccentButton("Save & Continue", 175, 250, 150, 36);
        nextBtn.Click += (_, _) =>
        {
            var key = apiInput.Text.Trim();
            if (string.IsNullOrEmpty(key) || key == "sk-...")
            {
                statusLabel.Text = "Please enter your API key";
                statusLabel.ForeColor = AccentColor;
                return;
            }

            if (Config.SaveAPIKey(key))
            {
                statusLabel.Text = "Saved!";
                statusLabel.ForeColor = GreenColor;
                ShowStep(3);
            }
            else
            {
                statusLabel.Text = "Failed to save key";
                statusLabel.ForeColor = Color.Red;
            }
        };
        _contentPanel.Controls.Add(nextBtn);

        var skipBtn = MakeLabel("Skip for now", 0, 300, 9, false);
        skipBtn.TextAlign = ContentAlignment.MiddleCenter;
        skipBtn.Size = new Size(500, 20);
        skipBtn.ForeColor = MutedColor;
        skipBtn.Cursor = Cursors.Hand;
        skipBtn.Click += (_, _) => ShowStep(3);
        _contentPanel.Controls.Add(skipBtn);
    }

    // --- Step 3: Finish ---
    private void ShowFinishStep()
    {
        var title = MakeLabel("You're all set!", 0, 80, 16, true);
        title.TextAlign = ContentAlignment.MiddleCenter;
        title.Size = new Size(500, 30);
        _contentPanel.Controls.Add(title);

        var check = MakeLabel("\u2713", 0, 130, 40, false);
        check.TextAlign = ContentAlignment.MiddleCenter;
        check.Size = new Size(500, 60);
        check.ForeColor = GreenColor;
        _contentPanel.Controls.Add(check);

        var desc = MakeLabel(
            "CustomWispr is running in your system tray.\n" +
            "Hold  Ctrl + Win  to start recording.",
            0, 210, 11, false);
        desc.TextAlign = ContentAlignment.MiddleCenter;
        desc.Size = new Size(500, 50);
        desc.ForeColor = MutedColor;
        _contentPanel.Controls.Add(desc);

        var doneBtn = MakeAccentButton("Done", 175, 290, 150, 36);
        doneBtn.Click += (_, _) =>
        {
            DialogResult = DialogResult.OK;
            Close();
        };
        _contentPanel.Controls.Add(doneBtn);
    }

    // --- Helpers ---

    private static Label MakeLabel(string text, int x, int y, float fontSize, bool bold)
    {
        return new Label
        {
            Text = text,
            Location = new Point(x, y),
            AutoSize = true,
            ForeColor = TextColor,
            BackColor = BgColor,
            Font = new Font("Segoe UI", fontSize, bold ? FontStyle.Bold : FontStyle.Regular)
        };
    }

    private static Button MakeAccentButton(string text, int x, int y, int w, int h)
    {
        return new Button
        {
            Text = text,
            Location = new Point(x, y),
            Size = new Size(w, h),
            FlatStyle = FlatStyle.Flat,
            BackColor = AccentColor,
            ForeColor = Color.Black,
            Font = new Font("Segoe UI", 10f, FontStyle.Bold),
            FlatAppearance = { BorderSize = 0 },
            Cursor = Cursors.Hand
        };
    }
}
