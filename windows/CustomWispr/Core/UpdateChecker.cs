using System;
using System.Diagnostics;
using System.Linq;
using System.Net.Http;
using System.Reflection;
using System.Text.Json;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace CustomWispr.Core;

internal static class UpdateChecker
{
    private const string Repo = "beausterling/CustomWispr";
    private static readonly string ApiURL = $"https://api.github.com/repos/{Repo}/releases/latest";

    public static async Task CheckForUpdates()
    {
        try
        {
            using var client = new HttpClient();
            client.Timeout = TimeSpan.FromSeconds(10);
            client.DefaultRequestHeaders.Add("Accept", "application/vnd.github+json");
            client.DefaultRequestHeaders.Add("User-Agent", "CustomWispr-Windows");

            var response = await client.GetStringAsync(ApiURL);
            using var doc = JsonDocument.Parse(response);
            var root = doc.RootElement;

            var tagName = root.GetProperty("tag_name").GetString() ?? "";
            var htmlUrl = root.GetProperty("html_url").GetString() ?? "";
            var body = root.TryGetProperty("body", out var bodyProp) ? bodyProp.GetString() : null;

            // Strip leading "v"
            var latestVersion = tagName.StartsWith("v") ? tagName[1..] : tagName;
            var currentVersion = Assembly.GetExecutingAssembly().GetName().Version?.ToString(2) ?? "0.0";

            Logger.Log($"Update check: current={currentVersion}, latest={latestVersion}");

            if (!IsNewer(latestVersion, currentVersion))
            {
                Logger.Log("App is up to date");
                return;
            }

            // Find Windows EXE asset
            string? exeUrl = null;
            if (root.TryGetProperty("assets", out var assets))
            {
                foreach (var asset in assets.EnumerateArray())
                {
                    var name = asset.GetProperty("name").GetString() ?? "";
                    if (name.EndsWith(".exe", StringComparison.OrdinalIgnoreCase) &&
                        (name.Contains("win", StringComparison.OrdinalIgnoreCase) ||
                         name.Contains("windows", StringComparison.OrdinalIgnoreCase)))
                    {
                        exeUrl = asset.GetProperty("browser_download_url").GetString();
                        break;
                    }
                }
            }

            ShowUpdateDialog(currentVersion, latestVersion, htmlUrl, exeUrl, body);
        }
        catch (Exception ex)
        {
            Logger.Log($"Update check failed: {ex.Message}");
        }
    }

    private static bool IsNewer(string newVer, string currentVer)
    {
        var newParts = newVer.Split('.').Select(s => int.TryParse(s, out var n) ? n : 0).ToArray();
        var curParts = currentVer.Split('.').Select(s => int.TryParse(s, out var n) ? n : 0).ToArray();
        var max = Math.Max(newParts.Length, curParts.Length);

        for (int i = 0; i < max; i++)
        {
            var n = i < newParts.Length ? newParts[i] : 0;
            var c = i < curParts.Length ? curParts[i] : 0;
            if (n > c) return true;
            if (n < c) return false;
        }
        return false;
    }

    private static void ShowUpdateDialog(string currentVersion, string newVersion,
        string releaseUrl, string? exeUrl, string? releaseNotes)
    {
        var message = $"CustomWispr v{newVersion} is available (you have v{currentVersion}).";
        if (!string.IsNullOrEmpty(releaseNotes))
        {
            var truncated = releaseNotes.Length > 300 ? releaseNotes[..300] + "..." : releaseNotes;
            message += $"\n\n{truncated}";
        }

        var buttons = exeUrl != null
            ? MessageBoxButtons.YesNoCancel
            : MessageBoxButtons.YesNo;
        var prompt = exeUrl != null
            ? $"{message}\n\nDownload update?"
            : $"{message}\n\nView release page?";

        var result = MessageBox.Show(prompt, "Update Available",
            buttons, MessageBoxIcon.Information);

        if (result == DialogResult.Yes)
        {
            var url = exeUrl ?? releaseUrl;
            Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });
        }
        else if (result == DialogResult.No && exeUrl != null)
        {
            Process.Start(new ProcessStartInfo(releaseUrl) { UseShellExecute = true });
        }
    }
}
