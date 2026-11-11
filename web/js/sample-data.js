/**
 * Dytava / ExcelCompare - Preloaded Sample Datasets
 */
export const SAMPLE_DATASETS = {
  academic: {
    name: "Bảng điểm & Hồ sơ học tập (Academic Records)",
    description: "So sánh dữ liệu điểm thi giữa hai phòng đào tạo (XLSX vs CSV). Kiểm tra phân biệt dấu thập phân (8.5 vs 8,5), mã sinh viên, và phát hiện thay đổi điểm.",
    keyColumn: "Mã SV",
    policyId: "academic-records-v1",
    fileA: {
      name: "BangDiem_PhongDaoTao_A.xlsx",
      format: "xlsx",
      headers: ["Mã SV", "Họ và tên", "Môn học", "Điểm số", "Xếp loại", "Trạng thái nộp"],
      rows: [
        ["SV001", "Nguyễn Văn An", "Toán cao cấp", "8.5", "Giỏi", "Đã nộp"],
        ["SV002", "Trần Thị Bích", "Toán cao cấp", "9.0", "Xuất sắc", "Đã nộp"],
        ["SV003", "Lê Hoàng Cường", "Toán cao cấp", "6.5", "Khá", "Đã nộp"],
        ["SV004", "Phạm Minh Đức", "Toán cao cấp", "5.0", "Trung bình", "Chưa nộp"],
        ["SV005", "Vũ Mai Hoa", "Toán cao cấp", "8.0", "Giỏi", "Đã nộp"],
        ["SV006", "Đặng Tuấn Kiệt", "Toán cao cấp", "7.5", "Khá", "Đã nộp"],
        ["SV007", "Bùi Thanh Lan", "Toán cao cấp", "9.5", "Xuất sắc", "Đã nộp"]
      ]
    },
    fileB: {
      name: "BangDiem_HeThong_B.csv",
      format: "csv",
      headers: ["Mã SV", "Họ và tên", "Môn học", "Điểm số", "Xếp loại", "Trạng thái nộp"],
      rows: [
        ["SV001", "Nguyễn Văn An", "Toán cao cấp", "8,5", "Giỏi", "Đã nộp"],      // Equivalent (locale decimal 8.5 vs 8,5)
        ["SV002", "Trần Thị Bích", "Toán cao cấp", "9.5", "Xuất sắc", "Đã nộp"],     // Different (9.0 vs 9.5)
        ["SV003", "Lê Hoàng Cường", "Toán cao cấp", "6.50", "Khá", "Đã nộp"],     // Equivalent (scale 6.5 vs 6.50)
        ["SV004", "Phạm Minh Đức", "Toán cao cấp", "5.0", "Trung bình", "Đã nộp"],  // Different (Chưa nộp vs Đã nộp)
        ["SV005", "Vũ Mai Hoa", "Toán cao cấp", "8.0", "Giỏi", "Đã nộp"],          // Exact
        ["SV006", "Đặng Tuấn Kiệt", "Toán cao cấp", "07/10", "Khá", "Đã nộp"],       // Unresolved (ambiguous score format 07/10)
        ["SV008", "Hoàng Kim Ngân", "Toán cao cấp", "8.8", "Giỏi", "Đã nộp"]       // Added row (SV008 is added, SV007 was removed)
      ]
    }
  },

  finance: {
    name: "Báo cáo Doanh thu & Chi phí Q3 vs Q4 (Finance & P&L)",
    description: "So sánh đối soát tài chính giữa hệ thống ERP nội bộ và báo cáo ngân hàng. Kiểm tra dung sai tiền tệ, tỷ lệ chiết khấu (%) và mã hạch toán.",
    keyColumn: "Mã giao dịch",
    policyId: "financial-audit-v2",
    fileA: {
      name: "ERP_DoanhThu_2026.xlsx",
      format: "xlsx",
      headers: ["Mã giao dịch", "Khách hàng", "Số tiền (VND)", "Chiết khấu", "Ngày ghi nhận", "Đã thanh toán"],
      rows: [
        ["TXN-1001", "Công ty ABC", "150000000", "5%", "15/09/2026", "Có"],
        ["TXN-1002", "Tập đoàn Vingroup", "420500000", "10%", "20/09/2026", "Có"],
        ["TXN-1003", "Công ty CP Sao Mai", "85200000", "0%", "28/09/2026", "Không"],
        ["TXN-1004", "Doanh nghiệp Hưng Thịnh", "230000000", "7.5%", "02/10/2026", "Có"],
        ["TXN-1005", "Công ty TNHH Hải Âu", "99000000", "2%", "10/10/2026", "Có"],
        ["TXN-1006", "Bảo hiểm Thăng Long", "310000000", "12%", "18/10/2026", "Không"]
      ]
    },
    fileB: {
      name: "NganHang_SaoKe_2026.csv",
      format: "csv",
      headers: ["Mã giao dịch", "Khách hàng", "Số tiền (VND)", "Chiết khấu", "Ngày ghi nhận", "Đã thanh toán"],
      rows: [
        ["TXN-1001", "Công ty ABC", "150,000,000", "0.05", "2026-09-15", "true"], // Equivalent (comma format, 5% = 0.05, date ISO, boolean true)
        ["TXN-1002", "Tập đoàn Vingroup", "420500000", "10%", "20/09/2026", "true"], // Exact/Equiv
        ["TXN-1003", "Công ty CP Sao Mai", "89000000", "0%", "28/09/2026", "false"], // Different (Amount 85.2M vs 89M)
        ["TXN-1004", "Doanh nghiệp Hưng Thịnh", "230000000", "0.075", "2026-10-02", "true"], // Equivalent
        ["TXN-1005", "Công ty TNHH Hải Âu", "99000000", "2%", "10/10/2026", "true"], // Exact
        ["TXN-1007", "Công nghệ Alpha", "145000000", "5%", "22/10/2026", "true"] // Added TXN-1007, Removed TXN-1006
      ]
    }
  },

  inventory: {
    name: "Kiểm kê Kho vận & SKU Vật tư (Supply Chain & Inventory)",
    description: "So sánh bảng kiểm kê thực tế tại kho và dữ liệu phần mềm WMS. Kiểm tra bảo toàn số 0 đứng trước (Leading zeros) ở mã SKU và trạng thái tồn kho.",
    keyColumn: "Mã SKU",
    policyId: "inventory-sku-v1",
    fileA: {
      name: "Kho_KiemKe_ThucTe.csv",
      format: "csv",
      headers: ["Mã SKU", "Tên sản phẩm", "Vị trí kệ", "Số lượng đếm", "Đơn giá", "Còn hàng"],
      rows: [
        ["00492", "Cáp sạc Type-C siêu bền 1m", "A1-02", "150", "85000", "ĐÚNG"],
        ["00812", "Chuột không dây Silent Pro", "B3-15", "84", "240000", "ĐÚNG"],
        ["01024", "Bàn phím cơ TKL RGB", "C2-08", "30", "890000", "ĐÚNG"],
        ["02048", "Đế tản nhiệt nhôm xoay 360", "D1-04", "0", "350000", "SAI"],
        ["03072", "Hub chuyển đổi 8 trong 1", "E4-11", "65", "620000", "ĐÚNG"]
      ]
    },
    fileB: {
      name: "WMS_DuLieu_HeThong.xlsx",
      format: "xlsx",
      headers: ["Mã SKU", "Tên sản phẩm", "Vị trí kệ", "Số lượng đếm", "Đơn giá", "Còn hàng"],
      rows: [
        ["00492", "Cáp sạc Type-C siêu bền 1m", "A1-02", "150", "85000", "true"], // Equivalent boolean
        ["00812", "Chuột không dây Silent Pro", "B3-15", "80", "240000", "true"],  // Different quantity (84 vs 80)
        ["1024", "Bàn phím cơ TKL RGB", "C2-08", "30", "890000", "true"],         // Unresolved/Different due to leading zero loss ("01024" vs "1024")
        ["02048", "Đế tản nhiệt nhôm xoay 360", "D1-04", "0", "350000", "false"], // Equivalent
        ["03072", "Hub chuyển đổi 8 trong 1", "E4-11", "65", "620000", "true"]   // Equivalent
      ]
    }
  }
};
