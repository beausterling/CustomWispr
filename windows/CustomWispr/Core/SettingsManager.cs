using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Windows.Forms;

namespace CustomWispr.Core;

internal class SettingsManager
{
    public static readonly SettingsManager Shared = new();

    private static readonly string SettingsPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
        ".custom-wispr-settings.json");

    public List<Replacement> Replacements { get; private set; } = new();
    public bool HasCompletedOnboarding { get; set; }
    public bool LaunchAtLogin { get; set; }

    // Hotkey settings — default: Ctrl+Win
    public Keys HotkeyKey { get; set; } = Keys.LWin;
    public Keys HotkeyModifiers { get; set; } = Keys.Control;

    private SettingsManager()
    {
        Load();
    }

    public string ApplyReplacements(string text)
    {
        var result = text;
        foreach (var r in Replacements)
        {
            if (string.IsNullOrEmpty(r.Find)) continue;
            result = result.Replace(r.Find, r.Replace ?? "", StringComparison.OrdinalIgnoreCase);
        }
        return result;
    }

    public void Load()
    {
        if (!File.Exists(SettingsPath)) return;

        try
        {
            var json = File.ReadAllText(SettingsPath);
            var data = JsonSerializer.Deserialize<SettingsData>(json);
            if (data != null)
            {
                Replacements = data.Replacements ?? new();
                HasCompletedOnboarding = data.HasCompletedOnboarding;
                LaunchAtLogin = data.LaunchAtLogin;
                if (!string.IsNullOrEmpty(data.HotkeyKey) && Enum.TryParse<Keys>(data.HotkeyKey, out var key))
                    HotkeyKey = key;
                if (!string.IsNullOrEmpty(data.HotkeyModifiers) && Enum.TryParse<Keys>(data.HotkeyModifiers, out var mods))
                    HotkeyModifiers = mods;
            }
        }
        catch (Exception ex)
        {
            Logger.Log($"Failed to load settings: {ex.Message}");
        }
    }

    public void Save()
    {
        try
        {
            var data = new SettingsData
            {
                Replacements = Replacements,
                HasCompletedOnboarding = HasCompletedOnboarding,
                LaunchAtLogin = LaunchAtLogin,
                HotkeyKey = HotkeyKey.ToString(),
                HotkeyModifiers = HotkeyModifiers.ToString()
            };

            var json = JsonSerializer.Serialize(data, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(SettingsPath, json);
        }
        catch (Exception ex)
        {
            Logger.Log($"Failed to save settings: {ex.Message}");
        }
    }

    public class Replacement
    {
        public string Find { get; set; } = "";
        public string Replace { get; set; } = "";
    }

    private class SettingsData
    {
        public List<Replacement>? Replacements { get; set; }
        public bool HasCompletedOnboarding { get; set; }
        public bool LaunchAtLogin { get; set; }
        public string? HotkeyKey { get; set; }
        public string? HotkeyModifiers { get; set; }
    }
}
