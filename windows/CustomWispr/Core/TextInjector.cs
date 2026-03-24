using System;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

namespace CustomWispr.Core;

internal class TextInjector
{
    public void Inject(string text)
    {
        // Must run on STA thread for clipboard access
        if (Thread.CurrentThread.GetApartmentState() != ApartmentState.STA)
        {
            var staThread = new Thread(() => DoInject(text));
            staThread.SetApartmentState(ApartmentState.STA);
            staThread.Start();
            staThread.Join();
        }
        else
        {
            DoInject(text);
        }
    }

    private static void DoInject(string text)
    {
        // 1. Save current clipboard contents
        IDataObject? savedClipboard = null;
        try
        {
            savedClipboard = Clipboard.GetDataObject();
        }
        catch { }

        // 2. Set our text on clipboard
        try
        {
            Clipboard.SetText(text, TextDataFormat.UnicodeText);
        }
        catch (Exception ex)
        {
            Logger.Log($"Failed to set clipboard: {ex.Message}");
            return;
        }

        // 3. Wait for clipboard to be ready
        Thread.Sleep(50);

        // 4. Simulate Ctrl+V
        SimulateCtrlV();

        // 5. Restore clipboard after a delay
        var savedData = savedClipboard;
        var restoreThread = new Thread(() =>
        {
            Thread.Sleep(150);
            try
            {
                if (savedData != null)
                    Clipboard.SetDataObject(savedData, true);
            }
            catch { }
        });
        restoreThread.SetApartmentState(ApartmentState.STA);
        restoreThread.Start();
    }

    private static void SimulateCtrlV()
    {
        var inputs = new NativeMethods.INPUT[4];

        // Ctrl down
        inputs[0] = MakeKeyInput(NativeMethods.VK_CONTROL, false);
        // V down
        inputs[1] = MakeKeyInput(NativeMethods.VK_V, false);
        // V up
        inputs[2] = MakeKeyInput(NativeMethods.VK_V, true);
        // Ctrl up
        inputs[3] = MakeKeyInput(NativeMethods.VK_CONTROL, true);

        NativeMethods.SendInput(4, inputs, Marshal.SizeOf<NativeMethods.INPUT>());
    }

    private static NativeMethods.INPUT MakeKeyInput(int vk, bool keyUp)
    {
        return new NativeMethods.INPUT
        {
            type = NativeMethods.INPUT_KEYBOARD,
            u = new NativeMethods.INPUTUNION
            {
                ki = new NativeMethods.KEYBDINPUT
                {
                    wVk = (ushort)vk,
                    dwFlags = keyUp ? NativeMethods.KEYEVENTF_KEYUP : 0
                }
            }
        };
    }
}
