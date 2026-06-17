# Security Local — Project-Specific Context

> File này bổ sung context riêng cho project. CLAUDE.md (master) sẽ tham chiếu file này.
> Đổi tên thành `security-local.md` để kích hoạt. Không commit file này nếu chứa thông tin nhạy cảm.

## Stack riêng project
- Database: (ví dụ: MongoDB thay Aurora MySQL)
- Framework: (ví dụ: FastAPI thay Flask)
- Queue: (ví dụ: RabbitMQ thay MSK)

## Ngoại lệ đã được Security Team duyệt
- (ví dụ: endpoint /public/health không cần auth — đã duyệt PR/MR #123)

## Quy tắc bổ sung cho project
- (ví dụ: tất cả response phải wrap trong envelope {data, error, meta})
