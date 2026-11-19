using System.Text.Json.Serialization;

namespace CGConvertor.Core.Transcode;

public sealed record EncoderProfile(string Id, string Label, string Container, string HintKey, string[] Args, string[]? ExtraMux = null);

/// <summary>
/// Registru de profile pentru Windows. Argumentele sunt cele software VERIFICATE ale clientului Windows 3.15
/// (format_registry.py, GPU_SOFTWARE): fără accelerare hardware activată automat. Disponibilitatea reală a
/// encoderelor în ffmpeg-ul împachetat se verifică la rulare (EncoderAvailability).
/// </summary>
public static class FormatRegistry
{
    public const string RewrapProfileId = "rewrap";

    public static readonly EncoderProfile[] All =
    {
        new("prores422", "ProRes 422", "mov", "codec.hint.proRes422", new[] { "-c:v", "prores_ks", "-profile:v", "2", "-pix_fmt", "yuv422p10le" }),
        new("prores422hq", "ProRes 422 HQ", "mov", "codec.hint.proRes422HQ", new[] { "-c:v", "prores_ks", "-profile:v", "3", "-pix_fmt", "yuv422p10le" }),
        new("prores422lt", "ProRes 422 LT", "mov", "codec.hint.proRes422LT", new[] { "-c:v", "prores_ks", "-profile:v", "1", "-pix_fmt", "yuv422p10le" }),
        new("prores4444", "ProRes 4444", "mov", "codec.hint.proRes4444", new[] { "-c:v", "prores_ks", "-profile:v", "4", "-pix_fmt", "yuva444p10le" }),
        new("dnxhd", "DNxHD", "mxf", "codec.hint.dnx", new[] { "-c:v", "dnxhd", "-profile:v", "dnxhd", "-b:v", "36M", "-pix_fmt", "yuv422p" }),
        new("dnxhrhq", "DNxHR HQ", "mxf", "codec.hint.dnx", new[] { "-c:v", "dnxhd", "-profile:v", "dnxhr_hq", "-qscale:v", "1", "-pix_fmt", "yuv422p" }),
        new("h264", "H.264", "mp4", "codec.hint.h264", new[] { "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p" }),
        new("hevc10", "HEVC 10-bit", "mp4", "codec.hint.hevc10", new[] { "-c:v", "libx265", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p10le" }, new[] { "-tag:v", "hvc1" }),
        new("av1", "AV1", "mp4", "codec.hint.av1", new[] { "-c:v", "libsvtav1", "-preset", "6", "-crf", "30" }),
        new("uncompressed", "Uncompressed 10-bit", "mov", "codec.hint.uncompressed", new[] { "-c:v", "v210" }),
    };

    public static EncoderProfile? Profile(string id) => All.FirstOrDefault(p => p.Id == id);

    /// <summary>Numele encoderului ffmpeg din argumentele profilului (după -c:v).</summary>
    public static string EncoderName(EncoderProfile p) => p.Args[Array.IndexOf(p.Args, "-c:v") + 1];
}

public enum AudioMode { Passthrough, Pcm16, Pcm24, Aac }
public enum ChannelLayout { Original, Stereo, Surround51 }
public enum ColorSpaceOption { Bt709, Bt2020 }

public static class OptionArgs
{
    public static string[] For(this AudioMode m) => m switch
    {
        AudioMode.Passthrough => new[] { "-c:a", "copy" },
        AudioMode.Pcm16 => new[] { "-c:a", "pcm_s16le" },
        AudioMode.Pcm24 => new[] { "-c:a", "pcm_s24le" },
        _ => new[] { "-c:a", "aac", "-b:a", "320k" },
    };
    public static string[] For(this ChannelLayout c) => c switch
    {
        ChannelLayout.Stereo => new[] { "-ac", "2" },
        ChannelLayout.Surround51 => new[] { "-ac", "6" },
        _ => Array.Empty<string>(),
    };
    public static string[] For(this ColorSpaceOption c) => c == ColorSpaceOption.Bt709
        ? new[] { "-vf", "setparams=color_primaries=bt709:color_trc=bt709:colorspace=bt709" }
        : new[] { "-vf", "setparams=color_primaries=bt2020:color_trc=bt2020-10:colorspace=bt2020nc" };
}

/// <summary>Preset de ieșire; JSON compatibil cu presets.json Mac/Windows (chei snake_case).</summary>
public sealed class OutputPreset
{
    /// Etichetă afișată: presetările integrate sunt traduse prin hook-ul clientului (RO/EN/ES); cele ale utilizatorului rămân cum le-a numit.
    public static Func<OutputPreset, string?>? Localizer { get; set; }
    [JsonIgnore] public string Display => (IsBuiltin ? Localizer?.Invoke(this) : null) ?? Label;
    public override string ToString() => Display;
    [JsonPropertyName("id")] public string Id { get; set; } = "";
    [JsonPropertyName("label")] public string Label { get; set; } = "";
    [JsonPropertyName("target_app")] public string TargetApp { get; set; } = "custom";
    [JsonPropertyName("profile_id")] public string ProfileId { get; set; } = "";
    [JsonPropertyName("audio_mode")] public string AudioModeRaw { get; set; } = "passthrough";
    [JsonPropertyName("channel_layout")] public string ChannelLayoutRaw { get; set; } = "original";
    [JsonPropertyName("file_suffix")] public string FileSuffix { get; set; } = "_convertit";
    [JsonPropertyName("is_builtin")] public bool IsBuiltin { get; set; }
    [JsonPropertyName("frame_rate")] public string? FrameRate { get; set; }
    [JsonPropertyName("color_space")] public string? ColorSpaceRaw { get; set; }

    [JsonIgnore] public AudioMode Audio => AudioModeRaw switch { "pcm16" => AudioMode.Pcm16, "pcm24" => AudioMode.Pcm24, "aac" => AudioMode.Aac, _ => AudioMode.Passthrough };
    [JsonIgnore] public ChannelLayout Channels => ChannelLayoutRaw switch { "stereo" => ChannelLayout.Stereo, "5.1" => ChannelLayout.Surround51, _ => ChannelLayout.Original };
    [JsonIgnore] public ColorSpaceOption? ColorSpace => ColorSpaceRaw switch { "bt709" => ColorSpaceOption.Bt709, "bt2020" => ColorSpaceOption.Bt2020, _ => null };
    [JsonIgnore] public bool IsRewrap => ProfileId == FormatRegistry.RewrapProfileId;
    [JsonIgnore] public string Extension => IsRewrap ? "mov" : FormatRegistry.Profile(ProfileId)?.Container ?? "mov";
}

public static class PresetsManager
{
    public static List<OutputPreset> Defaults() => new()
    {
        new() { Id = "builtin_rewrap", Label = "Rewrap Rapid", ProfileId = FormatRegistry.RewrapProfileId, FileSuffix = "_rewrap", IsBuiltin = true },
        new() { Id = "builtin_prores422hq", Label = "ProRes 422 HQ (Mezzanine DaVinci/FCP)", TargetApp = "davinci", ProfileId = "prores422hq", FileSuffix = "_proresHQ", IsBuiltin = true },
        new() { Id = "builtin_dnxhrhq", Label = "DNxHR HQ (Mezzanine Avid/Premiere)", TargetApp = "avid", ProfileId = "dnxhrhq", FileSuffix = "_dnxhr", IsBuiltin = true },
        new() { Id = "builtin_h264_web", Label = "H.264 (YouTube/Web, rezoluția sursei)", TargetApp = "web", ProfileId = "h264", AudioModeRaw = "aac", ChannelLayoutRaw = "stereo", FileSuffix = "_web", IsBuiltin = true },
        new() { Id = "builtin_hevc_master", Label = "HEVC 10-bit (Master Delivery)", ProfileId = "hevc10", AudioModeRaw = "aac", FileSuffix = "_master", IsBuiltin = true },
        new() { Id = "builtin_av1_web", Label = "AV1 (Web modern)", TargetApp = "web", ProfileId = "av1", AudioModeRaw = "aac", ChannelLayoutRaw = "stereo", FileSuffix = "_av1", IsBuiltin = true },
        new() { Id = "builtin_uncompressed", Label = "Uncompressed 10-bit (Arhivare)", ProfileId = "uncompressed", AudioModeRaw = "pcm24", FileSuffix = "_uncompressed", IsBuiltin = true },
    };
}
