package main

import (
	"fmt"
	"time"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"
)

type MinimalTestGUI struct {
	app         fyne.App
	window      fyne.Window
	startBtn    *widget.Button
	statusLabel *widget.Label
	logLabel    *widget.Label
	counter     int
}

func NewMinimalTestGUI() *MinimalTestGUI {
	myApp := app.New()
	myApp.SetIcon(theme.DocumentIcon())

	window := myApp.NewWindow("Minimal Test - Threading Check")
	window.Resize(fyne.NewSize(600, 400))

	gui := &MinimalTestGUI{
		app:     myApp,
		window:  window,
		counter: 0,
	}

	gui.setupUI()
	return gui
}

func (g *MinimalTestGUI) setupUI() {
	// Title
	title := widget.NewLabel("Minimal Threading Test")
	title.Alignment = fyne.TextAlignCenter
	title.TextStyle = fyne.TextStyle{Bold: true}

	// Status
	g.statusLabel = widget.NewLabel("Ready")
	g.statusLabel.Alignment = fyne.TextAlignCenter

	// Test button
	g.startBtn = widget.NewButton("Test UI Updates", g.onTestClick)
	g.startBtn.Importance = widget.HighImportance

	// Log display
	g.logLabel = widget.NewLabel("Click the button to test UI updates...")
	g.logLabel.Wrapping = fyne.TextWrapWord

	// Layout
	content := container.NewVBox(
		title,
		widget.NewSeparator(),
		g.statusLabel,
		widget.NewSeparator(),
		g.startBtn,
		widget.NewSeparator(),
		widget.NewLabel("Log Output:"),
		container.NewScroll(g.logLabel),
	)

	g.window.SetContent(content)
}

func (g *MinimalTestGUI) onTestClick() {
	g.counter++

	// Test immediate UI updates (should be safe from event handler)
	g.statusLabel.SetText(fmt.Sprintf("Test %d running...", g.counter))
	g.startBtn.Disable()

	// Update log immediately
	g.logLabel.SetText(fmt.Sprintf("Test %d started at %s", g.counter, time.Now().Format("15:04:05")))

	// Test background operation with UI updates
	go func() {
		time.Sleep(2 * time.Second)

		// This should cause threading violations if not handled properly
		// In a real app, we'd use proper channels/timers here

		// For this test, let's see if direct updates cause issues
		g.statusLabel.SetText(fmt.Sprintf("Test %d completed", g.counter))
		g.startBtn.Enable()

		currentLog := g.logLabel.Text
		newLog := currentLog + fmt.Sprintf("\nTest %d completed at %s", g.counter, time.Now().Format("15:04:05"))
		g.logLabel.SetText(newLog)
	}()
}

func (g *MinimalTestGUI) Run() {
	g.window.ShowAndRun()
}

// func main() {
// 	fmt.Println("Starting minimal Fyne threading test...")
// 	fmt.Println("This test will check if basic UI updates cause threading violations")
// 	fmt.Println("Watch for 'Error in Fyne call thread' messages")

// 	gui := NewMinimalTestGUI()
// 	gui.Run()

// 	fmt.Println("Test completed")
// }
