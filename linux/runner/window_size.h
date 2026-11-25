#ifndef RUNNER_WINDOW_SIZE_H_
#define RUNNER_WINDOW_SIZE_H_

// Window size rules, kept free of GTK so they can be compiled and tested on
// their own (test/linux/linux_window_size_test.dart).

constexpr int kMinWindowWidth = 360;
constexpr int kMinWindowHeight = 480;
constexpr int kDefaultWindowWidth = 1280;
constexpr int kDefaultWindowHeight = 720;
constexpr double kMaxWorkAreaFraction = 0.9;

struct WindowSize {
  int width;
  int height;
};

// The default window size for a monitor whose work area is
// `work_width` x `work_height`: 1280 x 720, at most 90 percent of the work
// area, never below the minimum.
inline WindowSize default_window_size(int work_width, int work_height) {
  int width = static_cast<int>(work_width * kMaxWorkAreaFraction);
  int height = static_cast<int>(work_height * kMaxWorkAreaFraction);
  if (width > kDefaultWindowWidth) width = kDefaultWindowWidth;
  if (height > kDefaultWindowHeight) height = kDefaultWindowHeight;
  if (width < kMinWindowWidth) width = kMinWindowWidth;
  if (height < kMinWindowHeight) height = kMinWindowHeight;
  return {width, height};
}

#endif  // RUNNER_WINDOW_SIZE_H_
