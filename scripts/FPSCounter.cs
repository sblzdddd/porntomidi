using Godot;
using System;

public partial class FPSCounter : Label
{
	public override void _Process(double delta)
	{
		this.Text = $"FPS: {(float)Engine.GetFramesPerSecond()}";
	}
}
