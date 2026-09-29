#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Sets window icon and ensures desktop integration (XDG icon and .desktop file)
// so that Wayland compositors (KDE KWin, GNOME Shell) properly associate the
// window with its icon in the titlebar, taskbar, and Alt+Tab switcher.
static void setup_application_icons(GtkWindow* window) {
  g_autofree gchar* exe_path = g_file_read_link("/proc/self/exe", nullptr);
  if (exe_path == nullptr) {
    return;
  }

  g_autofree gchar* dir = g_path_get_dirname(exe_path);
  // Bundle asset path: <bundle>/data/flutter_assets/assets/icons/logo.png
  g_autofree gchar* icon_path = g_build_filename(
      dir, "data", "flutter_assets", "assets", "icons", "logo.png", nullptr);

  if (!g_file_test(icon_path, G_FILE_TEST_EXISTS)) {
    // Fallback: check relative to working directory or source tree
    g_autofree gchar* fallback_path =
        g_build_filename("assets", "icons", "logo.png", nullptr);
    if (g_file_test(fallback_path, G_FILE_TEST_EXISTS)) {
      g_free(icon_path);
      icon_path = g_steal_pointer(&fallback_path);
    }
  }

  if (g_file_test(icon_path, G_FILE_TEST_EXISTS)) {
    // 1. Set window icon for X11 / GTK window decorations
    gtk_window_set_icon_from_file(window, icon_path, nullptr);

    // 2. Ensure XDG icon is installed for Wayland (KDE KWin, GNOME, etc.)
    const gchar* data_home = g_get_user_data_dir();
    g_autofree gchar* icon_dir = g_build_filename(
        data_home, "icons", "hicolor", "256x256", "apps", nullptr);
    g_autofree gchar* target_icon = g_build_filename(
        icon_dir, APPLICATION_ID ".png", nullptr);

    if (!g_file_test(target_icon, G_FILE_TEST_EXISTS)) {
      g_mkdir_with_parents(icon_dir, 0755);
      GFile* src = g_file_new_for_path(icon_path);
      GFile* dst = g_file_new_for_path(target_icon);
      g_file_copy(src, dst, G_FILE_COPY_OVERWRITE, nullptr, nullptr, nullptr, nullptr);
      g_object_unref(src);
      g_object_unref(dst);
    }

    // 3. Ensure .desktop file exists for Wayland app_id resolution
    g_autofree gchar* apps_dir = g_build_filename(data_home, "applications", nullptr);
    g_autofree gchar* target_desktop = g_build_filename(
        apps_dir, APPLICATION_ID ".desktop", nullptr);
    g_autofree gchar* sys_desktop = g_build_filename(
        "/usr/share/applications", APPLICATION_ID ".desktop", nullptr);

    if (!g_file_test(sys_desktop, G_FILE_TEST_EXISTS) &&
        !g_file_test(target_desktop, G_FILE_TEST_EXISTS)) {
      g_mkdir_with_parents(apps_dir, 0755);
      g_autofree gchar* desktop_content = g_strdup_printf(
          "[Desktop Entry]\n"
          "Name=Aniting\n"
          "Comment=Anime & Manga Client\n"
          "Exec=%s\n"
          "Icon=" APPLICATION_ID "\n"
          "Terminal=false\n"
          "Type=Application\n"
          "Categories=AudioVideo;Player;\n"
          "StartupWMClass=" APPLICATION_ID "\n",
          exe_path);
      g_file_set_contents(target_desktop, desktop_content, -1, nullptr);
    }
  }
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use standard native window decorations across all desktop environments
  // (GNOME, KDE Plasma, XFCE, tiling WMs, etc.). Avoids GtkHeaderBar which
  // in GTK3 enforces a bulky ~48-50px toolbar height instead of the standard
  // compact ~34px window titlebar.
  gtk_window_set_title(window, "Aniting");

  setup_application_icons(window);

  gtk_window_set_default_size(window, 1280, 720);

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

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
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
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
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
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
