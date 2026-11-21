#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"
#include "window_size.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// The work area of the monitor the window will most likely open on: the
// monitor under the pointer on X11; on Wayland the pointer position is unknown
// before a window is mapped, so this is the monitor at the origin. Falls back
// to the primary monitor. False when GDK reports none.
static gboolean get_work_area(GtkWindow* window, GdkRectangle* work_area) {
  GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(window));
  GdkMonitor* monitor = nullptr;
  GdkSeat* seat = gdk_display_get_default_seat(display);
  GdkDevice* pointer = seat != nullptr ? gdk_seat_get_pointer(seat) : nullptr;
  if (pointer != nullptr) {
    gint x = 0, y = 0;
    gdk_device_get_position(pointer, nullptr, &x, &y);
    monitor = gdk_display_get_monitor_at_point(display, x, y);
  }
  if (monitor == nullptr) monitor = gdk_display_get_primary_monitor(display);
  if (monitor == nullptr) return FALSE;
  gdk_monitor_get_workarea(monitor, work_area);
  return work_area->width > 0 && work_area->height > 0;
}

// GDK on X11 sets no _NET_WM_ICON for an icon over 262144 pixels, which rules
// out the 512 px asset, so both paths hand GTK a pixbuf scaled to this size.
static const int kWindowIconSize = 256;

// Sets the window icon: the installed theme icon named like the .desktop
// file's Icon= (the .deb, which ships only a 512 px entry), else the PNG
// shipped in the bundle's data dir (the tar.gz, which installs no theme entry).
static void set_window_icon(GtkWindow* window) {
  GtkIconTheme* theme = gtk_icon_theme_get_default();
  g_autoptr(GdkPixbuf) icon = nullptr;
  if (gtk_icon_theme_has_icon(theme, APPLICATION_ID)) {
    icon = gtk_icon_theme_load_icon(theme, APPLICATION_ID, kWindowIconSize,
                                    GTK_ICON_LOOKUP_FORCE_SIZE, nullptr);
  }
  if (icon == nullptr) {
    g_autofree gchar* exe = g_file_read_link("/proc/self/exe", nullptr);
    if (exe == nullptr) return;
    g_autofree gchar* dir = g_path_get_dirname(exe);
    g_autofree gchar* file =
        g_build_filename(dir, "data", "icons", APPLICATION_ID ".png", nullptr);
    icon = gdk_pixbuf_new_from_file_at_size(file, kWindowIconSize,
                                            kWindowIconSize, nullptr);
  }
  if (icon != nullptr) gtk_window_set_icon(window, icon);
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Hermes");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "Hermes");
  }

  // After both title paths, so the icon is set whichever one ran.
  set_window_icon(window);

  GdkGeometry min_size = {};
  min_size.min_width = kMinWindowWidth;
  min_size.min_height = kMinWindowHeight;
  gtk_window_set_geometry_hints(window, nullptr, &min_size, GDK_HINT_MIN_SIZE);

  WindowSize size = {kDefaultWindowWidth, kDefaultWindowHeight};
  GdkRectangle work_area;
  if (get_work_area(window, &work_area)) {
    size = default_window_size(work_area.width, work_area.height);
  }
  gtk_window_set_default_size(window, size.width, size.height);
  gtk_window_set_position(window, GTK_WIN_POS_CENTER);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::command_line. The unique primary instance gets the
// command line of every launch: its own, and the arguments of a later launch
// (a `hermes://` link from the desktop), which exits once this returns. The
// first one creates the window and passes its arguments to Dart (`main`, which
// reads a launch link); a later one presents the window, and the app_links
// plugin, hooked on the same signal, hands its link to Dart.
static gint my_application_command_line(GApplication* application,
                                        GApplicationCommandLine* command_line) {
  MyApplication* self = MY_APPLICATION(application);
  GList* windows = gtk_application_get_windows(GTK_APPLICATION(application));
  if (windows != nullptr) {
    g_message("Hermes: a later launch reached the running instance");
    gtk_window_present(GTK_WINDOW(windows->data));
    return 0;
  }
  gint argc = 0;
  g_auto(GStrv) arguments =
      g_application_command_line_get_arguments(command_line, &argc);
  // Strip out the first argument as it is the binary name.
  g_strfreev(self->dart_entrypoint_arguments);
  self->dart_entrypoint_arguments = g_strdupv(arguments + 1);
  g_application_activate(application);
  return 0;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->command_line = my_application_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_HANDLES_COMMAND_LINE,
                                     nullptr));
}
