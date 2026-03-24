using System;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace CustomWispr.Core;

internal class WhisperService
{
    private static readonly HttpClient Client = new()
    {
        Timeout = TimeSpan.FromSeconds(120)
    };

    public async Task<string> TranscribeAsync(string audioFilePath, CancellationToken ct = default)
    {
        try
        {
            return await AttemptTranscribe(audioFilePath, ct);
        }
        catch (Exception ex) when (IsTransient(ex))
        {
            Logger.Log($"Whisper request failed ({ex.Message}), retrying once...");
            await Task.Delay(500, ct);
            return await AttemptTranscribe(audioFilePath, ct);
        }
    }

    private static bool IsTransient(Exception ex)
    {
        if (ex is TaskCanceledException) return true;
        if (ex is HttpRequestException httpEx)
        {
            return httpEx.StatusCode is HttpStatusCode.InternalServerError
                or HttpStatusCode.BadGateway
                or HttpStatusCode.ServiceUnavailable
                or HttpStatusCode.GatewayTimeout
                or null; // network failure
        }
        return false;
    }

    private static async Task<string> AttemptTranscribe(string audioFilePath, CancellationToken ct)
    {
        using var content = new MultipartFormDataContent();
        content.Add(new StringContent(Config.WhisperModel), "model");
        content.Add(new StringContent("en"), "language");

        var audioBytes = await File.ReadAllBytesAsync(audioFilePath, ct);
        var audioContent = new ByteArrayContent(audioBytes);
        audioContent.Headers.ContentType = new MediaTypeHeaderValue("audio/wav");
        content.Add(audioContent, "file", "audio.wav");

        using var request = new HttpRequestMessage(HttpMethod.Post,
            $"{Config.OpenAIBaseURL}/audio/transcriptions");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", Config.ApiKey);
        request.Content = content;

        var response = await Client.SendAsync(request, ct);

        if (!response.IsSuccessStatusCode)
        {
            var errorBody = await response.Content.ReadAsStringAsync(ct);
            throw new HttpRequestException(
                $"Whisper API error ({(int)response.StatusCode}): {errorBody[..Math.Min(200, errorBody.Length)]}",
                null, response.StatusCode);
        }

        var json = await response.Content.ReadAsStringAsync(ct);
        using var doc = JsonDocument.Parse(json);
        return doc.RootElement.GetProperty("text").GetString() ?? "";
    }
}
