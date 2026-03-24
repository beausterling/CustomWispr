using System;
using System.IO;
using NAudio.Wave;

namespace CustomWispr.Core;

internal class AudioRecorder : IDisposable
{
    private WaveInEvent? _waveIn;
    private WaveFileWriter? _writer;
    private string? _tempFilePath;

    public string StartRecording()
    {
        _tempFilePath = Path.Combine(Path.GetTempPath(), $"custom-wispr_{Guid.NewGuid()}.wav");

        // 16kHz, 16-bit, mono — matches what Whisper uses internally
        _waveIn = new WaveInEvent
        {
            WaveFormat = new WaveFormat(16000, 16, 1),
            BufferMilliseconds = 50
        };

        _writer = new WaveFileWriter(_tempFilePath, _waveIn.WaveFormat);

        _waveIn.DataAvailable += (s, e) =>
        {
            _writer?.Write(e.Buffer, 0, e.BytesRecorded);
        };

        _waveIn.RecordingStopped += (s, e) =>
        {
            _writer?.Dispose();
            _writer = null;
        };

        _waveIn.StartRecording();
        Logger.Log("Recording started");

        return _tempFilePath;
    }

    public string? StopRecording()
    {
        _waveIn?.StopRecording();
        _waveIn?.Dispose();
        _waveIn = null;
        Logger.Log("Recording stopped");
        return _tempFilePath;
    }

    public void Cleanup()
    {
        if (_tempFilePath != null && File.Exists(_tempFilePath))
        {
            try { File.Delete(_tempFilePath); } catch { }
            _tempFilePath = null;
        }
    }

    /// <summary>Remove stale temp files from previous sessions</summary>
    public static void CleanupStaleFiles()
    {
        var tempDir = Path.GetTempPath();
        try
        {
            foreach (var file in Directory.GetFiles(tempDir, "custom-wispr_*.wav"))
            {
                try { File.Delete(file); } catch { }
            }
        }
        catch { }
    }

    public void Dispose()
    {
        _waveIn?.Dispose();
        _writer?.Dispose();
        GC.SuppressFinalize(this);
    }
}
