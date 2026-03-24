using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace CustomWispr.Core;

internal class GlobalKeyboardHook : IDisposable
{
    public event Action? OnHotkeyDown;
    public event Action? OnHotkeyUp;

    private IntPtr _hookHandle = IntPtr.Zero;
    private NativeMethods.LowLevelKeyboardProc? _hookProc;
    private bool _hotkeyIsDown;

    // Configurable hotkey — default: Ctrl+Win
    public Keys HotkeyKey { get; set; } = Keys.LWin;
    public Keys HotkeyModifiers { get; set; } = Keys.Control;

    public bool Start()
    {
        if (_hookHandle != IntPtr.Zero) return true;

        _hookProc = HookCallback;
        using var process = Process.GetCurrentProcess();
        using var module = process.MainModule!;
        _hookHandle = NativeMethods.SetWindowsHookEx(
            NativeMethods.WH_KEYBOARD_LL,
            _hookProc,
            NativeMethods.GetModuleHandle(module.ModuleName),
            0);

        if (_hookHandle == IntPtr.Zero)
        {
            Logger.Log("ERROR: Failed to install keyboard hook");
            return false;
        }

        Logger.Log("Keyboard hook installed successfully");
        return true;
    }

    public void Stop()
    {
        if (_hookHandle != IntPtr.Zero)
        {
            NativeMethods.UnhookWindowsHookEx(_hookHandle);
            _hookHandle = IntPtr.Zero;
            Logger.Log("Keyboard hook removed");
        }
    }

    private IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0)
        {
            int vkCode = Marshal.ReadInt32(lParam);
            int msg = wParam.ToInt32();

            bool isKeyDown = msg == NativeMethods.WM_KEYDOWN || msg == NativeMethods.WM_SYSKEYDOWN;
            bool isKeyUp = msg == NativeMethods.WM_KEYUP || msg == NativeMethods.WM_SYSKEYUP;

            if (IsHotkeyCombo(vkCode, isKeyDown))
            {
                if (isKeyDown && !_hotkeyIsDown)
                {
                    _hotkeyIsDown = true;
                    var ctx = System.Threading.SynchronizationContext.Current;
                    if (ctx != null)
                        ctx.Post(_ => OnHotkeyDown?.Invoke(), null);
                    else
                        OnHotkeyDown?.Invoke();
                    return (IntPtr)1; // Suppress
                }
            }

            // Detect release: if hotkey is down and any part of the combo is released
            if (_hotkeyIsDown && isKeyUp && IsPartOfHotkey(vkCode))
            {
                _hotkeyIsDown = false;
                var ctx = System.Threading.SynchronizationContext.Current;
                if (ctx != null)
                    ctx.Post(_ => OnHotkeyUp?.Invoke(), null);
                else
                    OnHotkeyUp?.Invoke();
                return (IntPtr)1; // Suppress
            }
        }

        return NativeMethods.CallNextHookEx(_hookHandle, nCode, wParam, lParam);
    }

    private bool IsHotkeyCombo(int vkCode, bool isKeyDown)
    {
        // Check if the pressed key is the main hotkey key
        if (vkCode != (int)HotkeyKey && !IsWinKey(vkCode)) return false;

        // For Win key, match either LWin or RWin
        if (HotkeyKey == Keys.LWin || HotkeyKey == Keys.RWin)
        {
            if (vkCode != NativeMethods.VK_LWIN && vkCode != NativeMethods.VK_RWIN)
                return false;
        }
        else if (vkCode != (int)HotkeyKey)
        {
            return false;
        }

        // Check modifiers are held
        return AreModifiersHeld();
    }

    private bool AreModifiersHeld()
    {
        if (HotkeyModifiers.HasFlag(Keys.Control))
        {
            if ((NativeMethods.GetAsyncKeyState(NativeMethods.VK_CONTROL) & 0x8000) == 0)
                return false;
        }

        if (HotkeyModifiers.HasFlag(Keys.Shift))
        {
            if ((NativeMethods.GetAsyncKeyState(0x10) & 0x8000) == 0) // VK_SHIFT
                return false;
        }

        if (HotkeyModifiers.HasFlag(Keys.Alt))
        {
            if ((NativeMethods.GetAsyncKeyState(0x12) & 0x8000) == 0) // VK_MENU
                return false;
        }

        return true;
    }

    private bool IsPartOfHotkey(int vkCode)
    {
        // Check if released key is part of the hotkey combo
        if (HotkeyKey == Keys.LWin || HotkeyKey == Keys.RWin)
        {
            if (vkCode == NativeMethods.VK_LWIN || vkCode == NativeMethods.VK_RWIN) return true;
        }
        else if (vkCode == (int)HotkeyKey) return true;

        if (HotkeyModifiers.HasFlag(Keys.Control) && vkCode == NativeMethods.VK_CONTROL) return true;
        if (HotkeyModifiers.HasFlag(Keys.Shift) && vkCode == 0x10) return true;
        if (HotkeyModifiers.HasFlag(Keys.Alt) && vkCode == 0x12) return true;

        return false;
    }

    private static bool IsWinKey(int vkCode) =>
        vkCode == NativeMethods.VK_LWIN || vkCode == NativeMethods.VK_RWIN;

    public void Dispose()
    {
        Stop();
        GC.SuppressFinalize(this);
    }
}
