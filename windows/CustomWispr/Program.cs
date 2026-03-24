using System;
using System.Threading;
using System.Windows.Forms;
using CustomWispr.UI;

namespace CustomWispr;

static class Program
{
    private static Mutex? _mutex;

    [STAThread]
    static void Main()
    {
        // Single instance check
        _mutex = new Mutex(true, @"Global\CustomWispr", out bool createdNew);
        if (!createdNew)
        {
            MessageBox.Show("CustomWispr is already running.", "CustomWispr",
                MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }

        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
        Application.Run(new TrayApplicationContext());
    }
}
