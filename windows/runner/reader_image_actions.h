#ifndef RUNNER_READER_IMAGE_ACTIONS_H_
#define RUNNER_READER_IMAGE_ACTIONS_H_

#include <windows.h>

#include <cstdint>
#include <vector>

// Copies top-down, straight-alpha RGBA pixels as a Windows clipboard bitmap.
bool CopyReaderImageToClipboard(HWND owner, const std::vector<uint8_t>& rgba,
                                int32_t width, int32_t height);

#endif  // RUNNER_READER_IMAGE_ACTIONS_H_
