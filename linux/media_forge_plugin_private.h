#include <flutter_linux/flutter_linux.h>

#include "include/media_forge/media_forge_plugin.h"

// This file exposes some plugin internals for unit testing. See
// https://github.com/flutter/flutter/issues/88724 for current limitations
// in the unit-testable API.

// Handles the getPlatformVersion method call, and returns the response as a
// gchar* so that it can be inspected in tests.
//
// The caller is responsible for freeing the return value.
gchar* media_forge_plugin_get_platform_version();
