# Đối chiếu native place 11380216916

Phạm vi của đợt kiểm tra này là place chính `11380216916 Star Glitcher Revitalized`. Logic và tính năng UltraHell không được dùng làm chuẩn, không được sửa, và không được tính vào kết quả dưới đây.

## Nguồn native được dùng làm chuẩn

- `ReplicatedStorage/Modules/BasicFunctions/init.luau`: `GetAllEntities`, `GetEntityRoot`, `GetEntityStatusFolder`, `GetEntityTeam`, `CanTeamHitTeam`, `CanTarget`.
- `ReplicatedStorage/Modules/StatusManager.luau`: cấu trúc `Status`, `Status.Attributes`, trạng thái `Stunned`, và các hệ số WalkSpeed/JumpPower.
- `StarterGui/BossIndicators/LocalScript.client.luau`: boss được xác định bằng attribute `IsBoss`; `NoIndicator` và `Invisible` chỉ điều khiển hiển thị indicator.
- `Workspace/Minigames/MinigameHandler/MinigameData.luau`: các entity minigame đặt `IsBoss` rõ ràng.

## Kết quả đối chiếu

| Hệ thống | Trước khi sửa | So với native | Kết quả hiện tại |
|---|---|---|---|
| Nguồn target | Quét nhiều folder theo heuristic | Đúng một phần | Vẫn hỗ trợ fallback, nhưng `workspace.Entities` được xem là nguồn có thẩm quyền và cập nhật bằng `ChildAdded/ChildRemoved`. |
| Loại tượng/ExtraNPC | Có thể lọt vào target list | Sai | Loại direct child của `workspace.ExtraNPC`, cùng các quan hệ `ParentEntity`. |
| Team và safe zone | Không áp dụng đầy đủ | Sai | Đọc `Status.Team`, `Status.SafeZoned`; loại team `-1`, cùng team khác FFA, và target trong safe zone. Team `0` giữ đúng hành vi FFA. |
| Nhận diện boss | Chủ yếu dựa tên/kích thước/health | Đúng một phần | `IsBoss=true/false` là kết quả có thẩm quyền; heuristic chỉ còn là fallback cho game/model không theo protocol native. |
| Cube, orb và summon lạ | Tên dạng prop có thể bị loại | Sai một phần | Model trực tiếp trong `Entities` không còn bị loại chỉ vì tên; non-Humanoid vẫn được hỗ trợ khi có bằng chứng combat. |
| Root/aim part | Có fallback rộng | Đúng một phần | Thứ tự root native được ưu tiên: `HumanoidRootPart`, `Torso`, `Head`; fallback `PrimaryPart/BasePart` chỉ dùng sau đó. |
| Predictor | Dùng chung vị trí theo dõi của tracker | Sai | Mẫu vị trí/thời gian thuộc riêng state predictor của từng target, tránh velocity bằng 0 giả khi model di chuyển bằng CFrame/PivotTo. |
| Estimator turn rate | Dùng member không tồn tại `Vector3.XZ` | Runtime error, chặn toàn bộ aim | Tính tốc độ ngang trực tiếp từ `X² + Z²`; check script chặn `XZ/XY/YZ` quay lại. |
| Aim Offset | Có option/UI nhưng không đi vào kết quả | Không hoạt động | Offset được áp dụng trong prediction engine kể cả khi tắt prediction. |
| Adaptive hit feedback | Mọi health delta gần shot đều có thể bị coi là hit | Không đáng tin hoàn toàn | Chuyển thành tùy chọn experimental và tắt mặc định để tránh học từ damage của người khác hoặc damage trễ. |
| Silent aim source | Camera/mouse ray từng bị buộc vào cửa sổ 0,35 giây | Regression ở 1.4.0 | Mouse/camera aim source redirect liên tục khi có target lock; remote và world side-effect ray vẫn chỉ rewrite trong cửa sổ bắn. Hook được version hóa để reload trong cùng session nhận logic mới. |
| No Stun | Chỉ chặn Humanoid state | Đúng một phần | Bổ sung adapter cho `Status/Status.Attributes` và xóa cờ CC theo cách không phá ValueObject; vẫn giữ Humanoid state guard. |
| No Slowdown | Ép mốc 16/50 và có thể xung đột form | Đúng một phần | Theo dõi baseline của Humanoid và nhường quyền cho speed override; không coi mọi form native đều có cùng WalkSpeed. |
| Attribute cleaner | Quét/xóa ValueBase và attribute theo tên chung | Sai, có thể phá game | Không còn destroy object hay xóa attribute chung; chỉ xử lý BoolValue CC trong cấu trúc status đã biết. |
| Noclip | Không trả lại `CanCollide` khi tắt | Không hoạt động đúng | Lưu và khôi phục giá trị gốc cho từng part khi tắt/destroy. |
| Clean Status Char | UI gọi biến không tồn tại | Không hoạt động | Controller truyền đúng cleaner và Rayfield; reset các option thực sự tồn tại. |
| Runtime UI loops | Player/Settings loop sống sau cleanup | Lỗi lifecycle | Cả hai controller được đăng ký vào runtime lifecycle và dừng khi destroy. |
| Auto debris cleanup | Mặc định bật, tag rộng gồm Orb/Effect/Visual | Không an toàn với native | Tắt mặc định, bỏ tag rộng, bảo vệ các root/entity/status/boss native; Smart Cleanup giờ thực sự điều khiển adaptive scheduling. |
| Loader/cache | Manifest dùng sai đường dẫn và jsDelivr `@main` có thể giữ bản cũ | Lỗi thời, dễ giữ cache cũ | Sửa bootstrap path, thêm Statically/GitHack trước jsDelivr, ghi nhớ CDN đang hoạt động cho rejoin, và tăng release lên `1.4.2`. |
| Teleport/config notification | Phụ thuộc global Rayfield ngầm | Đúng một phần | Rayfield được truyền rõ ràng vào Player, Settings và Teleport UI. |

## Giới hạn còn lại

- Aim assist/silent aim là logic phía client và phụ thuộc cách từng attack đọc mouse/camera ray. Native có nhiều kiểu attack khác nhau, nên không thể cam kết một hook duy nhất điều khiển chính xác mọi skill.
- `WalkSpeed`, `JumpPower`, teleport và status phía client có thể bị server ghi đè lại. Các tùy chọn movement hiện là tiện ích client, không phải bản thay thế cho hệ thống stat native.
- Speed spoof hiện chỉ che một phần truy cập property Humanoid; code native đọc `Status/Attributes` vẫn có thể thấy giá trị thật.
- Các module `Core/Brain.lua` và `Modules/Legacy/Prediction/*` không nằm trên đường chạy aim hiện tại. Chúng được giữ lại để tránh xóa code lịch sử ngoài phạm vi sửa lỗi.

## Kiểm tra hồi quy

- Luau specs: aim math, aim pipeline, native target policy, predictor state/feedback, loader, manifest, place profile, target classification.
- Selene: các module aim/tracker/policy chính.
- `luau-analyze`: policy/state thuần Luau.
- Graphify và CodeGraph: cập nhật lại đồ thị sau thay đổi.
