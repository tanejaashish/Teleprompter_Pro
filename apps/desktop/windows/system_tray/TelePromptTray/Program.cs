// apps/desktop/windows/system_tray/TelePromptTray/Program.cs

using System;
using System.Windows.Forms;
using H.NotifyIcon;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace TelePromptTray
{
    class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            Application.SetHighDpiMode(HighDpiMode.SystemAware);
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            var host = Host.CreateDefaultBuilder(args)
                .ConfigureServices((context, services) =>
                {
                    services.AddSingleton<TrayApplication>();
                    services.AddSingleton<FlutterBridge>();
                    services.AddSingleton<NotificationService>();
                    services.AddSingleton<HotkeyManager>();
                    services.AddSingleton<AutoStartManager>();
                })
                .Build();

            var app = host.Services.GetRequiredService<TrayApplication>();
            app.Run();
        }
    }

    // TrayApplication.cs
    public class TrayApplication : IDisposable
    {
        private TrayIcon _trayIcon;
        private readonly FlutterBridge _flutterBridge;
        private readonly NotificationService _notificationService;
        private readonly HotkeyManager _hotkeyManager;
        private readonly AutoStartManager _autoStartManager;
        private bool _isMainWindowVisible = false;

        public TrayApplication(
            FlutterBridge flutterBridge,
            NotificationService notificationService,
            HotkeyManager hotkeyManager,
            AutoStartManager autoStartManager)
        {
            _flutterBridge = flutterBridge;
            _notificationService = notificationService;
            _hotkeyManager = hotkeyManager;
            _autoStartManager = autoStartManager;
            InitializeTray();
            RegisterHotkeys();
        }

        private void InitializeTray()
        {
            _trayIcon = new TrayIcon
            {
                Icon = new System.Drawing.Icon("Resources/icon.ico"),
                ToolTipText = "TelePrompt Pro - Ready",
                Visible = true
            };

            _trayIcon.ContextMenu = CreateContextMenu();
            _trayIcon.DoubleClick += (s, e) => ShowMainWindow();
            _trayIcon.Click += (s, e) => ShowQuickMenu();

            // Set up Flutter bridge events
            _flutterBridge.OnScriptLoaded += OnScriptLoaded;
            _flutterBridge.OnRecordingStarted += OnRecordingStarted;
            _flutterBridge.OnRecordingStopped += OnRecordingStopped;
        }

        private PopupMenu CreateContextMenu()
        {
            var menu = new PopupMenu();

            // Quick Actions Section
            menu.Items.Add(new PopupMenuItem("📝 Quick Script", QuickScript) 
            { 
                IsDefault = true,
                ShortcutKeys = "Ctrl+Shift+N" 
            });
            
            menu.Items.Add(new PopupMenuItem("🎬 Start Recording", QuickRecord) 
            { 
                ShortcutKeys = "Ctrl+Shift+R" 
            });
            
            menu.Items.Add(new PopupMenuItem("📖 Open Recent", OpenRecentMenu()));
            
            menu.Items.Add(new PopupMenuSeparator());

            // Main Actions
            menu.Items.Add(new PopupMenuItem("🖥️ Show TelePrompt Pro", ShowMainWindow) 
            { 
                IsDefault = true,
                ShortcutKeys = "Ctrl+Shift+T" 
            });
            
            menu.Items.Add(new PopupMenuItem("⚡ Quick Launch Mode", QuickLaunchMode));
            
            menu.Items.Add(new PopupMenuSeparator());

            // Tools Section
            menu.Items.Add(new PopupMenuItem("🎤 Voice Control", ToggleVoiceControl) 
            { 
                IsCheckable = true,
                IsChecked = _flutterBridge.IsVoiceControlEnabled 
            });
            
            menu.Items.Add(new PopupMenuItem("📱 Mobile Sync", ShowMobileSync));
            
            menu.Items.Add(new PopupMenuItem("☁️ Cloud Status", ShowCloudStatus));
            
            menu.Items.Add(new PopupMenuSeparator());

            // Settings Section
            menu.Items.Add(new PopupMenuItem("🔧 Settings", ShowSettings));
            
            menu.Items.Add(new PopupMenuItem("🚀 Start with Windows", ToggleAutoStart) 
            { 
                IsCheckable = true,
                IsChecked = _autoStartManager.IsEnabled 
            });
            
            menu.Items.Add(new PopupMenuItem("🔔 Notifications", NotificationSettings));
            
            menu.Items.Add(new PopupMenuSeparator());

            // Help & Exit
            menu.Items.Add(new PopupMenuItem("❓ Help", ShowHelp));
            menu.Items.Add(new PopupMenuItem("ℹ️ About", ShowAbout));
            menu.Items.Add(new PopupMenuSeparator());
            menu.Items.Add(new PopupMenuItem("❌ Exit", Exit) 
            { 
                ShortcutKeys = "Alt+F4" 
            });

            return menu;
        }

        private PopupMenu OpenRecentMenu()
        {
            var recentMenu = new PopupMenu();
            var recentScripts = _flutterBridge.GetRecentScripts();

            if (recentScripts.Count == 0)
            {
                recentMenu.Items.Add(new PopupMenuItem("No recent scripts") { IsEnabled = false });
            }
            else
            {
                foreach (var script in recentScripts.Take(10))
                {
                    recentMenu.Items.Add(new PopupMenuItem(
                        $"📄 {script.Title}", 
                        () => OpenScript(script.Id)
                    ));
                }
                
                recentMenu.Items.Add(new PopupMenuSeparator());
                recentMenu.Items.Add(new PopupMenuItem("Clear Recent", ClearRecent));
            }

            return recentMenu;
        }

        private void RegisterHotkeys()
        {
            _hotkeyManager.RegisterHotkey("ShowHide", Keys.T, KeyModifiers.Control | KeyModifiers.Shift, 
                ShowMainWindow);
            _hotkeyManager.RegisterHotkey("QuickRecord", Keys.R, KeyModifiers.Control | KeyModifiers.Shift, 
                QuickRecord);
            _hotkeyManager.RegisterHotkey("QuickScript", Keys.N, KeyModifiers.Control | KeyModifiers.Shift, 
                QuickScript);
            _hotkeyManager.RegisterHotkey("PlayPause", Keys.Space, KeyModifiers.Control | KeyModifiers.Shift, 
                TogglePlayPause);
            _hotkeyManager.RegisterHotkey("VoiceControl", Keys.V, KeyModifiers.Control | KeyModifiers.Shift, 
                ToggleVoiceControl);
        }

        private void ShowMainWindow()
        {
            _flutterBridge.ShowMainWindow();
            _isMainWindowVisible = true;
            UpdateTrayIcon();
        }

        private void QuickScript()
        {
            _flutterBridge.CreateNewScript();
            _notificationService.ShowNotification(
                "Quick Script",
                "New script created and ready for editing",
                NotificationType.Info,
                actions: new[] { 
                    ("Edit", () => _flutterBridge.ShowScriptEditor()),
                    ("Cancel", null)
                }
            );
        }

        private void QuickRecord()
        {
            if (_flutterBridge.IsRecording)
            {
                _flutterBridge.StopRecording();
                _notificationService.ShowNotification(
                    "Recording Stopped",
                    "Your recording has been saved",
                    NotificationType.Success
                );
            }
            else
            {
                _flutterBridge.StartRecording();
                _notificationService.ShowNotification(
                    "Recording Started",
                    "TelePrompt Pro is now recording",
                    NotificationType.Info,
                    actions: new[] { ("Stop", () => _flutterBridge.StopRecording()) }
                );
            }
            UpdateTrayIcon();
        }

        private void QuickLaunchMode()
        {
            var dialog = new QuickLaunchDialog(_flutterBridge);
            dialog.ShowDialog();
        }

        private void ToggleVoiceControl()
        {
            _flutterBridge.ToggleVoiceControl();
            var status = _flutterBridge.IsVoiceControlEnabled ? "enabled" : "disabled";
            _notificationService.ShowNotification(
                "Voice Control",
                $"Voice control has been {status}",
                NotificationType.Info
            );
        }

        private void TogglePlayPause()
        {
            _flutterBridge.TogglePlayPause();
        }

        private void ShowMobileSync()
        {
            var syncStatus = _flutterBridge.GetSyncStatus();
            var dialog = new MobileSyncDialog(syncStatus);
            dialog.ShowDialog();
        }

        private void ShowCloudStatus()
        {
            var cloudStatus = _flutterBridge.GetCloudStatus();
            var message = $"Storage: {cloudStatus.UsedSpace}/{cloudStatus.TotalSpace} GB\n" +
                         $"Scripts: {cloudStatus.ScriptCount}\n" +
                         $"Last Sync: {cloudStatus.LastSyncTime}";
            
            _notificationService.ShowNotification(
                "Cloud Status",
                message,
                NotificationType.Info
            );
        }

        private void ShowSettings()
        {
            _flutterBridge.ShowSettings();
        }

        private void ToggleAutoStart()
        {
            _autoStartManager.Toggle();
            var status = _autoStartManager.IsEnabled ? "enabled" : "disabled";
            _notificationService.ShowNotification(
                "Auto Start",
                $"Auto start has been {status}",
                NotificationType.Info
            );
        }

        private void NotificationSettings()
        {
            var dialog = new NotificationSettingsDialog(_notificationService);
            dialog.ShowDialog();
        }

        private void ShowQuickMenu()
        {
            // Show a quick floating menu near the cursor
            var quickMenu = new QuickActionMenu(_flutterBridge);
            quickMenu.Show();
        }

        private void OpenScript(string scriptId)
        {
            _flutterBridge.OpenScript(scriptId);
            ShowMainWindow();
        }

        private void ClearRecent()
        {
            _flutterBridge.ClearRecentScripts();
            _notificationService.ShowNotification(
                "Recent Scripts",
                "Recent scripts list has been cleared",
                NotificationType.Info
            );
        }

        private void ShowHelp()
        {
            System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
            {
                FileName = "https://teleprompt.pro/help",
                UseShellExecute = true
            });
        }

        private void ShowAbout()
        {
            var about = new AboutDialog();
            about.ShowDialog();
        }

        private void Exit()
        {
            if (_flutterBridge.IsRecording)
            {
                var result = MessageBox.Show(
                    "Recording is in progress. Stop recording and exit?",
                    "TelePrompt Pro",
                    MessageBoxButtons.YesNo,
                    MessageBoxIcon.Warning
                );

                if (result == DialogResult.Yes)
                {
                    _flutterBridge.StopRecording();
                }
                else
                {
                    return;
                }
            }

            _trayIcon.Visible = false;
            Application.Exit();
        }

        private void UpdateTrayIcon()
        {
            if (_flutterBridge.IsRecording)
            {
                _trayIcon.Icon = new System.Drawing.Icon("Resources/icon_recording.ico");
                _trayIcon.ToolTipText = "TelePrompt Pro - Recording";
            }
            else if (_isMainWindowVisible)
            {
                _trayIcon.Icon = new System.Drawing.Icon("Resources/icon_active.ico");
                _trayIcon.ToolTipText = "TelePrompt Pro - Active";
            }
            else
            {
                _trayIcon.Icon = new System.Drawing.Icon("Resources/icon.ico");
                _trayIcon.ToolTipText = "TelePrompt Pro - Ready";
            }
        }

        // Event handlers
        private void OnScriptLoaded(string scriptTitle)
        {
            _notificationService.ShowNotification(
                "Script Loaded",
                $"'{scriptTitle}' is ready in the teleprompter",
                NotificationType.Info
            );
        }

        private void OnRecordingStarted()
        {
            UpdateTrayIcon();
        }

        private void OnRecordingStopped(string filePath)
        {
            UpdateTrayIcon();
            _notificationService.ShowNotification(
                "Recording Saved",
                $"Your recording has been saved",
                NotificationType.Success,
                actions: new[] { 
                    ("Open", () => System.Diagnostics.Process.Start("explorer.exe", $"/select,\"{filePath}\"")),
                    ("Share", () => _flutterBridge.ShareRecording(filePath))
                }
            );
        }

        public void Run()
        {
            Application.Run();
        }

        public void Dispose()
        {
            _hotkeyManager?.Dispose();
            _trayIcon?.Dispose();
            _flutterBridge?.Dispose();
        }
    }

    // FlutterBridge.cs - Communication with Flutter app
    public class FlutterBridge : IDisposable
    {
        private Process _flutterProcess;
        private NamedPipeServerStream _pipeServer;
        private readonly string _pipeName = "TelePromptProPipe";
        
        public bool IsRecording { get; private set; }
        public bool IsVoiceControlEnabled { get; private set; }
        
        public event Action<string> OnScriptLoaded;
        public event Action OnRecordingStarted;
        public event Action<string> OnRecordingStopped;

        public FlutterBridge()
        {
            InitializePipe();
            StartFlutterApp();
        }

        private void InitializePipe()
        {
            Task.Run(async () =>
            {
                _pipeServer = new NamedPipeServerStream(_pipeName, PipeDirection.InOut);
                await _pipeServer.WaitForConnectionAsync();
                ListenForMessages();
            });
        }

        private void StartFlutterApp()
        {
            // Start the Flutter app if not already running
            if (!IsFlutterAppRunning())
            {
                _flutterProcess = Process.Start(new ProcessStartInfo
                {
                    FileName = "teleprompt_pro.exe",
                    Arguments = "--hidden", // Start minimized to tray
                    UseShellExecute = false,
                    CreateNoWindow = true
                });
            }
        }

        private bool IsFlutterAppRunning()
        {
            return Process.GetProcessesByName("teleprompt_pro").Any();
        }

        public void ShowMainWindow()
        {
            SendCommand("show_window");
        }

        public void CreateNewScript()
        {
            SendCommand("new_script");
        }

        public void StartRecording()
        {
            SendCommand("start_recording");
            IsRecording = true;
            OnRecordingStarted?.Invoke();
        }

        public void StopRecording()
        {
            SendCommand("stop_recording");
            IsRecording = false;
        }

        public void ToggleVoiceControl()
        {
            SendCommand("toggle_voice_control");
            IsVoiceControlEnabled = !IsVoiceControlEnabled;
        }

        public void TogglePlayPause()
        {
            SendCommand("toggle_play_pause");
        }

        public List<ScriptInfo> GetRecentScripts()
        {
            var response = SendCommandWithResponse("get_recent_scripts");
            return JsonSerializer.Deserialize<List<ScriptInfo>>(response);
        }

        public void OpenScript(string scriptId)
        {
            SendCommand($"open_script:{scriptId}");
        }

        public void ShowScriptEditor()
        {
            SendCommand("show_script_editor");
        }

        public void ShowSettings()
        {
            SendCommand("show_settings");
        }

        public SyncStatus GetSyncStatus()
        {
            var response = SendCommandWithResponse("get_sync_status");
            return JsonSerializer.Deserialize<SyncStatus>(response);
        }

        public CloudStatus GetCloudStatus()
        {
            var response = SendCommandWithResponse("get_cloud_status");
            return JsonSerializer.Deserialize<CloudStatus>(response);
        }

        public void ShareRecording(string filePath)
        {
            SendCommand($"share_recording:{filePath}");
        }

        public void ClearRecentScripts()
        {
            SendCommand("clear_recent_scripts");
        }

        private void SendCommand(string command)
        {
            if (_pipeServer?.IsConnected == true)
            {
                var writer = new StreamWriter(_pipeServer);
                writer.WriteLine(command);
                writer.Flush();
            }
        }

        private string SendCommandWithResponse(string command)
        {
            if (_pipeServer?.IsConnected == true)
            {
                var writer = new StreamWriter(_pipeServer);
                var reader = new StreamReader(_pipeServer);
                writer.WriteLine(command);
                writer.Flush();
                return reader.ReadLine();
            }
            return null;
        }

        private void ListenForMessages()
        {
            Task.Run(async () =>
            {
                var reader = new StreamReader(_pipeServer);
                while (_pipeServer.IsConnected)
                {
                    var message = await reader.ReadLineAsync();
                    if (message != null)
                    {
                        ProcessMessage(message);
                    }
                }
            });
        }

        private void ProcessMessage(string message)
        {
            var parts = message.Split(':');
            var command = parts[0];
            var data = parts.Length > 1 ? parts[1] : null;

            switch (command)
            {
                case "script_loaded":
                    OnScriptLoaded?.Invoke(data);
                    break;
                case "recording_stopped":
                    OnRecordingStopped?.Invoke(data);
                    break;
            }
        }

        public void Dispose()
        {
            _pipeServer?.Dispose();
            if (_flutterProcess != null && !_flutterProcess.HasExited)
            {
                _flutterProcess.Kill();
            }
        }
    }
}