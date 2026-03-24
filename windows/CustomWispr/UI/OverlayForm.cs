using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace CustomWispr.UI;

internal class OverlayForm : Form
{
    private string _statusText = "";

    public OverlayForm()
    {
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        TopMost = true;
        StartPosition = FormStartPosition.Manual;
        Size = new Size(200, 40);
        DoubleBuffered = true;

        // Position: center-bottom of primary screen
        PositionOnScreen();
    }

    private void PositionOnScreen()
    {
        var screen = Screen.PrimaryScreen?.WorkingArea ?? new Rectangle(0, 0, 1920, 1080);
        Location = new Point(
            screen.Left + (screen.Width - Width) / 2,
            screen.Bottom - Height - 100);
    }

    protected override bool ShowWithoutActivation => true;

    protected override CreateParams CreateParams
    {
        get
        {
            var cp = base.CreateParams;
            cp.ExStyle |= NativeMethods.WS_EX_NOACTIVATE
                        | NativeMethods.WS_EX_TOOLWINDOW
                        | NativeMethods.WS_EX_TRANSPARENT;
            return cp;
        }
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        var g = e.Graphics;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;

        // Pill-shaped background
        var rect = new Rectangle(0, 0, Width, Height);
        var radius = Height;
        using var path = CreateRoundedRect(rect, radius);
        using var brush = new SolidBrush(Color.FromArgb(216, 26, 26, 26));
        g.FillPath(brush, path);

        // Status text
        using var font = new Font("Segoe UI", 11f, FontStyle.Regular);
        using var textBrush = new SolidBrush(Color.White);
        var textSize = g.MeasureString(_statusText, font);
        var x = (Width - textSize.Width) / 2;
        var y = (Height - textSize.Height) / 2;
        g.DrawString(_statusText, font, textBrush, x, y);
    }

    private static GraphicsPath CreateRoundedRect(Rectangle rect, int diameter)
    {
        var path = new GraphicsPath();
        var arc = new Rectangle(rect.Location, new Size(diameter, diameter));

        path.AddArc(arc, 180, 90); // Top-left
        arc.X = rect.Right - diameter;
        path.AddArc(arc, 270, 90); // Top-right
        arc.Y = rect.Bottom - diameter;
        path.AddArc(arc, 0, 90);   // Bottom-right
        arc.X = rect.Left;
        path.AddArc(arc, 90, 90);  // Bottom-left
        path.CloseFigure();

        return path;
    }

    public void ShowOverlay(string status)
    {
        if (InvokeRequired)
        {
            BeginInvoke(() => ShowOverlay(status));
            return;
        }

        _statusText = status;
        PositionOnScreen();

        // Set the window region to the pill shape for transparency
        using var path = CreateRoundedRect(new Rectangle(0, 0, Width, Height), Height);
        Region = new Region(path);

        Invalidate();
        Show();
    }

    public void HideOverlay()
    {
        if (InvokeRequired)
        {
            BeginInvoke(HideOverlay);
            return;
        }

        Hide();
    }
}
