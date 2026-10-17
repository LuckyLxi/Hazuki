#include "reader_image_actions.h"

#include <limits>

bool CopyReaderImageToClipboard(HWND owner, const std::vector<uint8_t>& rgba,
                                int32_t width, int32_t height) {
  if (width <= 0 || height <= 0) {
    return false;
  }
  const uint64_t pixel_bytes = static_cast<uint64_t>(width) * height * 4;
  if (pixel_bytes != rgba.size() ||
      pixel_bytes > std::numeric_limits<DWORD>::max() ||
      pixel_bytes >
          std::numeric_limits<size_t>::max() - sizeof(BITMAPV5HEADER)) {
    return false;
  }

  const size_t allocation_size =
      sizeof(BITMAPV5HEADER) + static_cast<size_t>(pixel_bytes);
  HGLOBAL bitmap = GlobalAlloc(GMEM_MOVEABLE | GMEM_ZEROINIT, allocation_size);
  if (!bitmap) {
    return false;
  }
  auto* header = static_cast<BITMAPV5HEADER*>(GlobalLock(bitmap));
  if (!header) {
    GlobalFree(bitmap);
    return false;
  }
  header->bV5Size = sizeof(BITMAPV5HEADER);
  header->bV5Width = width;
  header->bV5Height = -height;
  header->bV5Planes = 1;
  header->bV5BitCount = 32;
  header->bV5Compression = BI_BITFIELDS;
  header->bV5SizeImage = static_cast<DWORD>(pixel_bytes);
  header->bV5RedMask = 0x00ff0000;
  header->bV5GreenMask = 0x0000ff00;
  header->bV5BlueMask = 0x000000ff;
  header->bV5AlphaMask = 0xff000000;
  header->bV5CSType = LCS_sRGB;
  auto* bgra = reinterpret_cast<uint8_t*>(header + 1);
  for (size_t i = 0; i < rgba.size(); i += 4) {
    bgra[i] = rgba[i + 2];
    bgra[i + 1] = rgba[i + 1];
    bgra[i + 2] = rgba[i];
    bgra[i + 3] = rgba[i + 3];
  }
  GlobalUnlock(bitmap);

  if (!OpenClipboard(owner)) {
    GlobalFree(bitmap);
    return false;
  }
  const bool copied =
      EmptyClipboard() && SetClipboardData(CF_DIBV5, bitmap) != nullptr;
  CloseClipboard();
  if (!copied) {
    GlobalFree(bitmap);
  }
  // On success, the clipboard owns the allocation.
  return copied;
}
