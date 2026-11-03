# Cloudflare Tunnel (macOS)

App macOS mở **Cloudflare Tunnel** cho các port đang chạy trên máy: mỗi port một dòng, nhập port rồi **Start** để có URL `https://…` truy cập từ bất kỳ mạng nào (HTTP và WebSocket).
Tính năng tunnel lấy từ [LocalServer](https://github.com/catgaming-asia/LocalServer).

Ví dụ Nakama: lần mở đầu app có sẵn 2 dòng **Nakama API** (`7350`) và **Nakama Console** (`7351`). Chạy Nakama, bấm **Start** từng dòng (hoặc **Start All**):

| Port | Dùng | Ở client |
|---|---|---|
| 7350 | API + socket realtime | host = `<xxx>.trycloudflare.com`, port `443`, scheme `https` (socket `wss`) |
| 7351 | Console web | mở URL trong trình duyệt |

## Cài đặt

```bash
brew install cloudflared
```

Mở app: `open build/CloudflareTunnel.app` (đã commit sẵn). Build lại: bấm đúp `build/build-app.command` hoặc `swift run` khi đang sửa code. Cần macOS 14+ và Xcode (Swift 5.9+).

## Dùng

- **Add Port** thêm dòng, 🗑 xoá dòng. Danh sách được lưu lại.
- Mỗi dòng: **Name**, **Port**, *listening / not listening* (app kiểm `localhost:<port>` mỗi 3 giây), **HTTPS origin** (bật khi server local tự chạy https, không kiểm chứng chỉ).
- **Quick**: URL ngẫu nhiên `https://<từ-ngẫu-nhiên>.trycloudflare.com`, không cần tài khoản, đổi mỗi lần Start.
- **Custom domain**: URL cố định `https://<domain>`; domain phải là zone trong tài khoản Cloudflare.
  **Logout** (khi đã đăng nhập) chuyển `cert.pem` vào Thùng rác; tunnel đang chạy vẫn chạy, muốn Start Custom domain thì Login lại.
  1. **Login…** một lần trên máy (khung *Cloudflare*). Ở trang **Authorize Cloudflare Tunnel** chọn zone (vd. `example.com`) rồi bấm **Authorize** → có `~/.cloudflared/cert.pem`.
  2. Nhập **Domain** (vd. `nakama.example.com`) và **Tunnel** (tên tunnel riêng cho mỗi dòng, vd. `nakama-api`, `nakama-console`).
  3. **Start** tự tạo tunnel (nếu chưa có) và bản ghi DNS (ghi đè bản ghi cũ).
- **Copy / Open** URL công khai; khung **Log** hiện cảnh báo/lỗi của `cloudflared`.
- Icon đám mây trên menu bar: Start/Stop từng port, copy URL khi đã đóng cửa sổ. Thoát app sẽ tắt mọi `cloudflared`.

Ai có URL đều truy cập được port đó; chỉ mở khi cần và Stop khi xong.
