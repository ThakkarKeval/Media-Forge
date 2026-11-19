#include <gtest/gtest.h>
#include <windows.h>

#include <memory>
#include <string>
#include <variant>

#include "messages.g.h"
#include "media_forge_plugin.h"

// This demonstrates a simple unit test of the C++ portion of this plugin's
// implementation.
//
// Once you have built the plugin's example app, you can run these tests
// from the command line. For instance, for an x64 debug build, run:
// $ build\windows\x64\plugins\media_forge/Debug\media_forge_test.exe

namespace media_forge {
namespace test {

TEST(MediaForgePlugin, GetPlatformVersion) {
  MediaForgePlugin plugin;
  ErrorOr<std::string> result = plugin.GetPlatformVersion();

  EXPECT_FALSE(result.has_error());
  // Since the exact string varies by host, just ensure that it's a string
  // with the expected format.
  std::string result_string = result.value();
  EXPECT_TRUE(result_string.rfind("Windows ", 0) == 0);
}

}  // namespace test
}  // namespace media_forge
