using System;
using System.IO;
using System.Security.AccessControl;
using System.Security.Principal;

namespace CustomWispr.Core;

internal static class Config
{
    public const string WhisperModel = "whisper-1";
    public const string GptModel = "gpt-4o-mini";
    public const string OpenAIBaseURL = "https://api.openai.com/v1";

    private static readonly string EnvFilePath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
        ".custom-wispr.env");

    public static string ApiKey
    {
        get
        {
            var key = ReadKeyFromEnvFile();
            if (!string.IsNullOrEmpty(key)) return key;

            key = Environment.GetEnvironmentVariable("OPENAI_API_KEY");
            if (!string.IsNullOrEmpty(key)) return key;

            return string.Empty;
        }
    }

    public static bool HasAPIKey => !string.IsNullOrEmpty(ApiKey);

    public static bool SaveAPIKey(string key)
    {
        try
        {
            File.WriteAllText(EnvFilePath, $"OPENAI_API_KEY={key}\n");

            // Set file permissions to owner-only (Windows equivalent of chmod 600)
            var fileInfo = new FileInfo(EnvFilePath);
            var security = fileInfo.GetAccessControl();
            security.SetAccessRuleProtection(true, false); // Remove inherited rules
            var currentUser = WindowsIdentity.GetCurrent().Name;
            security.AddAccessRule(new FileSystemAccessRule(
                currentUser, FileSystemRights.FullControl, AccessControlType.Allow));
            fileInfo.SetAccessControl(security);

            return true;
        }
        catch (Exception ex)
        {
            Logger.Log($"ERROR: Failed to save API key: {ex.Message}");
            return false;
        }
    }

    private static string? ReadKeyFromEnvFile()
    {
        if (!File.Exists(EnvFilePath)) return null;

        try
        {
            foreach (var line in File.ReadAllLines(EnvFilePath))
            {
                var trimmed = line.Trim();
                if (trimmed.StartsWith("OPENAI_API_KEY="))
                {
                    var value = trimmed["OPENAI_API_KEY=".Length..].Trim().Trim('"', '\'');
                    return string.IsNullOrEmpty(value) ? null : value;
                }
            }
        }
        catch { }

        return null;
    }
}

internal static class Logger
{
    public static void Log(string message)
    {
        var timestamp = DateTime.UtcNow.ToString("o");
        Console.Error.WriteLine($"[{timestamp}] CustomWispr: {message}");
    }
}
