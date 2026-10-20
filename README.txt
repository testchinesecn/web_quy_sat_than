QUỶ SÁT THẦN ONLINE - LANDING PAGE

CẬP NHẬT LINK TỰ ĐỘNG (WINDOWS)

1) Nhấp đúp CAP_NHAT_LINK.cmd trong thư mục này, hoặc chạy file đó từ CMD.
2) Dán link iOS mới rồi Enter; không đổi thì chỉ nhấn Enter.
3) Làm tương tự với link PC, rồi APK.
4) Chương trình tự cập nhật các nút tải, commit và push lên origin/main.
5) Đợi GitHub Pages triển khai (thường khoảng 1–2 phút), rồi tải lại web.

Yêu cầu: có Git for Windows, kết nối Internet và tài khoản GitHub có quyền
push vào repository. Nếu Git hiện cửa sổ đăng nhập, đăng nhập tài khoản đó.
Giữ CAP_NHAT_LINK.cmd và thư mục scripts trong bản clone Git hiện tại.
Chương trình tự lấy bản mới nhất từ GitHub trước khi hỏi link. Nếu thư mục
đang có thay đổi chưa commit hoặc commit chưa push, chương trình sẽ báo
để bạn xử lý trước. Enter cả ba lần sẽ không tạo commit và không push.
Link không hợp lệ sẽ được yêu cầu nhập lại. Link bỏ qua được giữ nguyên.
Nếu đã commit nhưng push lỗi, mở CMD tại thư mục này và chạy:
git push origin main

CẬP NHẬT THỦ CÔNG

1) Mở assets/js/config.js
2) Dán link Google Drive bản PC vào pc
3) Dán link Google Drive APK vào android
4) Dán link nhóm Zalo vào zalo
5) Upload toàn bộ thư mục lên GitHub repository
6) GitHub > Settings > Pages > Deploy from branch > main > /(root)

Không có backend, database hay mã hóa ảnh. Web chỉ dùng HTML/CSS/JS + 4 ảnh WebP.
