# Cloudflare Tunnel (macOS)

App macOS mở **Cloudflare Tunnel** cho các port đang chạy trên máy: mỗi port một dòng, nhập port rồi **Start** để có URL `https://…` truy cập từ bất kỳ mạng nào (HTTP và WebSocket).
Tính năng tunnel lấy từ [LocalServer](https://github.com/catgaming-asia/LocalServer).

Lần mở đầu app có 1 dòng trống: điền **Port** rồi bấm **Start**; cần thêm port thì **Add Port**. Ví dụ Nakama: thêm 2 dòng `7350` và `7351`, Start từng dòng (hoặc **Start All**):

| Port | Dùng | Ở client |
|---|---|---|
| 7350 | API + socket realtime | host = `<xxx>.trycloudflare.com`, port `443`, scheme `https` (socket `wss`) |
| 7351 | Console web | mở URL trong trình duyệt |

## Cài đặt

```bash
brew install cloudflared
```

Mở app: `open build/CloudflareTunnel.app` (đã commit sẵn). Build lại: bấm đúp `build/build-app.command` hoặc `swift run` khi đang sửa code. Ký bằng chứng chỉ Apple Development giống Local Server (máy không có thì ký ad-hoc; đổi bằng `CLOUDFLARETUNNEL_SIGN_IDENTITY`). Cần macOS 14+ và Xcode (Swift 5.9+).

## Cập nhật (Check for Updates)

App tự kiểm bản mới khi mở (có bản mới thì hiện thanh xanh **Update…**), hoặc **Cloudflare Tunnel › Check for Updates…** / menu bar.
App đọc `latest.json` ở thư mục công khai trên R2 (mặc định `https://data.catgaming.asia/CloudflareTunnel/release/`, đổi trong **Settings…**),
tải zip, kiểm kích thước + SHA-256 + bundle id + version, rồi thay app và mở lại.

Phát hành bản mới (trên nhánh `main`, working tree sạch):

```bash
build/release.command            # patch; hoặc minor | major | 1.2.0, thêm --notes "..." nếu muốn
```

Script tăng `VERSION`, build lại `build/CloudflareTunnel.app`, commit `Release v<x>` + tag `v<x>`, tạo `build/release/CloudflareTunnel-<x>.zip` và `latest.json`,
rồi hỏi có push không. Sau đó tải **zip trước, `latest.json` sau** lên `CloudflareTunnel/release/` trong bucket R2 và purge cache `latest.json`.

## Dùng

- **Add Port** thêm dòng, 🗑 xoá dòng. Danh sách được lưu lại.
- Mỗi dòng: **Name** (tuỳ chọn, chỉ để hiển thị), **Port** (port của server trên máy), *listening / not listening* (app kiểm `localhost:<port>` mỗi 3 giây), **HTTPS origin** (bật khi server local tự chạy https, không kiểm chứng chỉ).
- **Quick**: URL ngẫu nhiên `https://<từ-ngẫu-nhiên>.trycloudflare.com`, không cần tài khoản, đổi mỗi lần Start.
- **Custom domain**: URL cố định `https://<domain>`; domain phải là zone trong tài khoản Cloudflare.
  **Logout** (khi đã đăng nhập) chuyển `cert.pem` vào Thùng rác; tunnel đang chạy vẫn chạy, muốn Start Custom domain thì Login lại.
  1. **Login…** một lần trên máy (khung *Cloudflare*). Ở trang **Authorize Cloudflare Tunnel** chọn zone (vd. `example.com`) rồi bấm **Authorize** → có `~/.cloudflared/cert.pem`.
  2. Nhập **Domain** (vd. `api.example.com`) và **Tunnel name**: tên tunnel trên tài khoản Cloudflare, đặt tuỳ ý (vd. `my-api`; để trống = `tunnel-<port>`), mỗi domain một tên. Start lần đầu tự tạo; đã có thì dùng lại.
  3. **Start** tự tạo tunnel (nếu chưa có) và bản ghi DNS (ghi đè bản ghi cũ).
- **Copy / Open** URL công khai; khung **Log** hiện cảnh báo/lỗi của `cloudflared`.
- Icon đám mây trên menu bar: Start/Stop từng port, copy URL khi đã đóng cửa sổ. Thoát app sẽ tắt mọi `cloudflared`.

Ai có URL đều truy cập được port đó; chỉ mở khi cần và Stop khi xong.
