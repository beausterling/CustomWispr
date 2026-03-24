using System;
using System.Diagnostics;
using System.Drawing;
using System.Windows.Forms;
using CustomWispr.Core;
using Microsoft.Win32;

namespace CustomWispr.UI;

internal class SettingsForm : Form
{
    // Dark theme colors (matching macOS version)
    private static readonly Color BgColor = Color.FromArgb(14, 14, 16);       // #0e0e10
    private static readonly Color TextColor = Color.FromArgb(232, 230, 227);  // #e8e6e3
    private static readonly Color MutedColor = Color.FromArgb(148, 146, 157); // #94929d
    private static readonly Color AccentColor = Color.FromArgb(245, 158, 11); // #f59e0b
    private static readonly Color CardBg = Color.FromArgb(8, 255, 255, 255);
    private static readonly Color BorderColor = Color.FromArgb(20, 255, 255, 255);
    private static readonly Color GreenColor = Color.FromArgb(34, 197, 94);   // #22c55e

    private readonly TabControl _tabs;
    private string _realApiKey = "";
    private TextBox? _apiKeyInput;
    private Label? _apiKeyStatus;
    private DataGridView? _replaceGrid;

    public SettingsForm()
    {
        Text = "CustomWispr Settings";
        Size = new Size(500, 420);
        StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.FixedSingle;
        MaximizeBox = false;
        BackColor = BgColor;
        ForeColor = TextColor;

        // Dark title bar on Windows 10/11
        EnableDarkTitleBar();

        _tabs = new TabControl
        {
            Dock = DockStyle.Fill,
            DrawMode = TabDrawMode.OwnerDrawFixed,
            ItemSize = new Size(150, 30)
        };
        _tabs.DrawItem += DrawTab;

        _tabs.TabPages.Add(CreateApiKeyTab());
        _tabs.TabPages.Add(CreateFindReplaceTab());
        _tabs.TabPages.Add(CreateCustomizeTab());

        Controls.Add(_tabs);
    }

    private void EnableDarkTitleBar()
    {
        var value = 1;
        NativeMethods.DwmSetWindowAttribute(Handle,
            NativeMethods.DWMWA_USE_IMMERSIVE_DARK_MODE, ref value, sizeof(int));
    }

    private void DrawTab(object? sender, DrawItemEventArgs e)
    {
        var tab = _tabs.TabPages[e.Index];
        var isSelected = _tabs.SelectedIndex == e.Index;

        using var bgBrush = new SolidBrush(BgColor);
        e.Graphics.FillRectangle(bgBrush, e.Bounds);

        using var textBrush = new SolidBrush(isSelected ? AccentColor : MutedColor);
        using var font = new Font("Segoe UI", 10f, isSelected ? FontStyle.Bold : FontStyle.Regular);
        var textSize = e.Graphics.MeasureString(tab.Text, font);
        var x = e.Bounds.Left + (e.Bounds.Width - textSize.Width) / 2;
        var y = e.Bounds.Top + (e.Bounds.Height - textSize.Height) / 2;
        e.Graphics.DrawString(tab.Text, font, textBrush, x, y);

        if (isSelected)
        {
            using var accentPen = new Pen(AccentColor, 2);
            e.Graphics.DrawLine(accentPen,
                e.Bounds.Left + 10, e.Bounds.Bottom - 1,
                e.Bounds.Right - 10, e.Bounds.Bottom - 1);
        }
    }

    // --- API Key Tab ---

    private TabPage CreateApiKeyTab()
    {
        var page = new TabPage("API Key") { BackColor = BgColor };
        var panel = new Panel { Dock = DockStyle.Fill, Padding = new Padding(20) };
        page.Controls.Add(panel);

        var y = 20;

        // API key label
        panel.Controls.Add(MakeLabel("OpenAI API Key", 20, y, bold: true));
        y += 30;

        // API key input (masked)
        _realApiKey = Config.ApiKey;
        _apiKeyInput = new TextBox
        {
            Location = new Point(20, y),
            Size = new Size(340, 28),
            BackColor = Color.FromArgb(30, 30, 34),
            ForeColor = TextColor,
            BorderStyle = BorderStyle.FixedSingle,
            Font = new Font("Segoe UI", 10f),
            Text = MaskKey(_realApiKey)
        };
        _apiKeyInput.GotFocus += (_, _) =>
        {
            if (_apiKeyInput.Text == MaskKey(_realApiKey))
                _apiKeyInput.Text = _realApiKey;
        };
        _apiKeyInput.LostFocus += (_, _) =>
        {
            _realApiKey = _apiKeyInput.Text;
            _apiKeyInput.Text = MaskKey(_realApiKey);
        };
        panel.Controls.Add(_apiKeyInput);

        var saveBtn = MakeButton("Save", 370, y, 80, 28);
        saveBtn.Click += (_, _) => SaveApiKey();
        panel.Controls.Add(saveBtn);
        y += 40;

        // Status
        _apiKeyStatus = MakeLabel(
            Config.HasAPIKey ? "API key configured" : "No API key set",
            20, y);
        _apiKeyStatus.ForeColor = Config.HasAPIKey ? GreenColor : AccentColor;
        panel.Controls.Add(_apiKeyStatus);
        y += 40;

        // Hotkey label
        panel.Controls.Add(MakeLabel("Hotkey (hold to record)", 20, y, bold: true));
        y += 30;

        var hotkeyLabel = MakeLabel(GetHotkeyDisplayString(), 20, y);
        hotkeyLabel.ForeColor = MutedColor;
        panel.Controls.Add(hotkeyLabel);
        y += 40;

        // Launch at login
        var loginCheck = new CheckBox
        {
            Text = "Launch at login",
            Location = new Point(20, y),
            AutoSize = true,
            ForeColor = TextColor,
            BackColor = BgColor,
            Font = new Font("Segoe UI", 10f),
            Checked = SettingsManager.Shared.LaunchAtLogin
        };
        loginCheck.CheckedChanged += (_, _) =>
        {
            SettingsManager.Shared.LaunchAtLogin = loginCheck.Checked;
            SettingsManager.Shared.Save();
            SetLaunchAtLogin(loginCheck.Checked);
        };
        panel.Controls.Add(loginCheck);

        return page;
    }

    private void SaveApiKey()
    {
        var key = _apiKeyInput?.Text ?? "";
        if (key == MaskKey(_realApiKey)) key = _realApiKey;

        if (string.IsNullOrWhiteSpace(key))
        {
            if (_apiKeyStatus != null) { _apiKeyStatus.Text = "Please enter a key"; _apiKeyStatus.ForeColor = AccentColor; }
            return;
        }

        _realApiKey = key;
        if (Config.SaveAPIKey(key))
        {
            if (_apiKeyStatus != null) { _apiKeyStatus.Text = "API key saved!"; _apiKeyStatus.ForeColor = GreenColor; }
            if (_apiKeyInput != null) _apiKeyInput.Text = MaskKey(key);
        }
        else
        {
            if (_apiKeyStatus != null) { _apiKeyStatus.Text = "Failed to save"; _apiKeyStatus.ForeColor = Color.Red; }
        }
    }

    private static string MaskKey(string key)
    {
        if (string.IsNullOrEmpty(key)) return "";
        if (key.Length <= 8) return new string('\u2022', key.Length);
        return key[..4] + new string('\u2022', key.Length - 8) + key[^4..];
    }

    private static string GetHotkeyDisplayString()
    {
        var mods = SettingsManager.Shared.HotkeyModifiers;
        var key = SettingsManager.Shared.HotkeyKey;
        var parts = new System.Collections.Generic.List<string>();
        if (mods.HasFlag(Keys.Control)) parts.Add("Ctrl");
        if (mods.HasFlag(Keys.Shift)) parts.Add("Shift");
        if (mods.HasFlag(Keys.Alt)) parts.Add("Alt");
        parts.Add(key == Keys.LWin || key == Keys.RWin ? "Win" : key.ToString());
        return string.Join(" + ", parts);
    }

    // --- Find & Replace Tab ---

    private TabPage CreateFindReplaceTab()
    {
        var page = new TabPage("Find & Replace") { BackColor = BgColor };
        var panel = new Panel { Dock = DockStyle.Fill, Padding = new Padding(20) };
        page.Controls.Add(panel);

        panel.Controls.Add(MakeLabel("Find & Replace Rules", 20, 20, bold: true));

        _replaceGrid = new DataGridView
        {
            Location = new Point(20, 55),
            Size = new Size(430, 220),
            BackgroundColor = Color.FromArgb(30, 30, 34),
            ForeColor = TextColor,
            DefaultCellStyle = { BackColor = Color.FromArgb(30, 30, 34), ForeColor = TextColor, SelectionBackColor = Color.FromArgb(50, 50, 60) },
            ColumnHeadersDefaultCellStyle = { BackColor = BgColor, ForeColor = MutedColor },
            EnableHeadersVisualStyles = false,
            GridColor = Color.FromArgb(50, 50, 60),
            BorderStyle = BorderStyle.FixedSingle,
            AllowUserToResizeRows = false,
            RowHeadersVisible = false,
            AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.Fill,
            SelectionMode = DataGridViewSelectionMode.FullRowSelect
        };

        _replaceGrid.Columns.Add("Find", "Find");
        _replaceGrid.Columns.Add("Replace", "Replace With");

        foreach (var r in SettingsManager.Shared.Replacements)
            _replaceGrid.Rows.Add(r.Find, r.Replace);

        panel.Controls.Add(_replaceGrid);

        var addBtn = MakeButton("+", 20, 285, 40, 28);
        addBtn.Click += (_, _) => _replaceGrid.Rows.Add("", "");
        panel.Controls.Add(addBtn);

        var removeBtn = MakeButton("-", 65, 285, 40, 28);
        removeBtn.Click += (_, _) =>
        {
            if (_replaceGrid.SelectedRows.Count > 0 && !_replaceGrid.SelectedRows[0].IsNewRow)
                _replaceGrid.Rows.Remove(_replaceGrid.SelectedRows[0]);
        };
        panel.Controls.Add(removeBtn);

        var saveBtn = MakeButton("Save", 370, 285, 80, 28);
        saveBtn.Click += (_, _) => SaveReplacements();
        panel.Controls.Add(saveBtn);

        return page;
    }

    private void SaveReplacements()
    {
        if (_replaceGrid == null) return;

        SettingsManager.Shared.Replacements.Clear();
        foreach (DataGridViewRow row in _replaceGrid.Rows)
        {
            if (row.IsNewRow) continue;
            var find = row.Cells[0].Value?.ToString() ?? "";
            var replace = row.Cells[1].Value?.ToString() ?? "";
            if (!string.IsNullOrEmpty(find))
                SettingsManager.Shared.Replacements.Add(new SettingsManager.Replacement { Find = find, Replace = replace });
        }
        SettingsManager.Shared.Save();
    }

    // --- Customize Tab ---

    private TabPage CreateCustomizeTab()
    {
        var page = new TabPage("Customize") { BackColor = BgColor };
        var panel = new Panel { Dock = DockStyle.Fill, Padding = new Padding(20) };
        page.Controls.Add(panel);

        var y = 20;
        panel.Controls.Add(MakeLabel("Customize with AI", 20, y, bold: true));
        y += 30;

        var desc = MakeLabel(
            "Copy the prompt below and paste it into Claude or ChatGPT along with\n" +
            "the CustomWispr source code to customize the app to your needs.",
            20, y);
        desc.Size = new Size(430, 40);
        desc.ForeColor = MutedColor;
        panel.Controls.Add(desc);
        y += 55;

        var promptBox = new TextBox
        {
            Location = new Point(20, y),
            Size = new Size(430, 100),
            Multiline = true,
            ReadOnly = true,
            BackColor = Color.FromArgb(30, 30, 34),
            ForeColor = MutedColor,
            BorderStyle = BorderStyle.FixedSingle,
            Font = new Font("Consolas", 9f),
            Text = "Fork and clone https://github.com/beausterling/CustomWispr — it's a macOS menu bar speech-to-text app built in Swift. Read the README and codebase, then help me customize it."
        };
        panel.Controls.Add(promptBox);
        y += 115;

        var copyBtn = MakeButton("Copy Prompt", 20, y, 120, 28);
        copyBtn.Click += (_, _) =>
        {
            Clipboard.SetText(promptBox.Text);
            copyBtn.Text = "Copied!";
            var timer = new System.Windows.Forms.Timer { Interval = 2000 };
            timer.Tick += (_, _) => { copyBtn.Text = "Copy Prompt"; timer.Stop(); };
            timer.Start();
        };
        panel.Controls.Add(copyBtn);

        var ghBtn = MakeButton("View on GitHub", 150, y, 130, 28);
        ghBtn.Click += (_, _) => Process.Start(new ProcessStartInfo("https://github.com/beausterling/CustomWispr") { UseShellExecute = true });
        panel.Controls.Add(ghBtn);

        return page;
    }

    // --- Helpers ---

    private static Label MakeLabel(string text, int x, int y, bool bold = false)
    {
        return new Label
        {
            Text = text,
            Location = new Point(x, y),
            AutoSize = true,
            ForeColor = TextColor,
            BackColor = BgColor,
            Font = new Font("Segoe UI", 10f, bold ? FontStyle.Bold : FontStyle.Regular)
        };
    }

    private static Button MakeButton(string text, int x, int y, int w, int h)
    {
        return new Button
        {
            Text = text,
            Location = new Point(x, y),
            Size = new Size(w, h),
            FlatStyle = FlatStyle.Flat,
            BackColor = Color.FromArgb(40, 40, 46),
            ForeColor = TextColor,
            Font = new Font("Segoe UI", 9f),
            FlatAppearance = { BorderColor = Color.FromArgb(60, 60, 70), BorderSize = 1 }
        };
    }

    private static void SetLaunchAtLogin(bool enable)
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(
                @"Software\Microsoft\Windows\CurrentVersion\Run", true);
            if (key == null) return;

            if (enable)
                key.SetValue("CustomWispr", $"\"{Application.ExecutablePath}\"");
            else
                key.DeleteValue("CustomWispr", false);
        }
        catch (Exception ex)
        {
            Logger.Log($"Failed to set launch at login: {ex.Message}");
        }
    }
}
