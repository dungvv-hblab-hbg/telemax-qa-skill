/**
 * Test data gom một chỗ, không rải giá trị hardcode trong thân test.
 * Case nào cần dữ liệu đặc thù (VD "xe đang có engine fault") thì khai báo ở đây
 * và ghi rõ điều kiện, để người khác biết cần seed gì trên staging.
 */

export const VEHICLE = {
  // TODO: thay bằng xe thật trên staging, dùng xe dành riêng cho QA.
  rego: '51A-12345',
  name: 'Truck 07 — North Depot',
};

export const DEVICE = {
  // TODO: thiết bị có dữ liệu ổn định, không bị người khác sửa.
  imei: '000000000000000',
};

/** Xe đang báo lỗi engine — cần seed trước, không phải lúc nào cũng có. */
export const VEHICLE_WITH_FAULT = {
  rego: '',   // để trống nghĩa là chưa seed -> case liên quan đánh [MANUAL]
};
