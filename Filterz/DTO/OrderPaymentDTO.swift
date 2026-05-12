// OrderPaymentDTO.swift

import Foundation

// MARK: - Order Response DTOs

nonisolated struct OrderCreateResponseDTO: Decodable, Sendable {
    let orderId: String?
    let orderCode: String
    let totalPrice: Int
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case orderCode = "order_code"
        case totalPrice = "total_price"
        case createdAt, updatedAt
    }
}

nonisolated struct OrderResponseDTO: Decodable, Sendable {
    let orderId: String
    let orderCode: String
    let filter: FilterSummaryResponseDTO_Order
    let paidAt: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case orderCode = "order_code"
        case filter, paidAt, createdAt, updatedAt
        case paidAtSnake = "paid_at"
        case createdAtSnake = "created_at"
        case updatedAtSnake = "updated_at"
    }

    init(
        orderId: String,
        orderCode: String,
        filter: FilterSummaryResponseDTO_Order,
        paidAt: String?,
        createdAt: String,
        updatedAt: String
    ) {
        self.orderId = orderId
        self.orderCode = orderCode
        self.filter = filter
        self.paidAt = paidAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        orderId = try container.decode(String.self, forKey: .orderId)
        orderCode = try container.decode(String.self, forKey: .orderCode)
        filter = try container.decode(FilterSummaryResponseDTO_Order.self, forKey: .filter)
        paidAt = try container.decodeIfPresent(String.self, forKey: .paidAt)
            ?? container.decodeIfPresent(String.self, forKey: .paidAtSnake)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
            ?? container.decodeIfPresent(String.self, forKey: .createdAtSnake)
            ?? ""
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
            ?? container.decodeIfPresent(String.self, forKey: .updatedAtSnake)
            ?? ""
    }
}

nonisolated struct OrderListResponseDTO: Decodable, Sendable {
    let data: [OrderResponseDTO]
}

nonisolated struct ReceiptOrderResponseDTO: Decodable, Sendable {
    let paymentId: String
    let orderItem: OrderResponseDTO
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case paymentId = "payment_id"
        case orderItem = "order_item"
        case createdAt, updatedAt
    }
}

nonisolated struct ReceiptOrderListResponseDTO: Decodable, Sendable {
    let data: [ReceiptOrderResponseDTO]
}

// MARK: - Payment Response DTOs

nonisolated struct PaymentResponseDTO: Decodable, Sendable {
    let impUid: String?
    let merchantUid: String?
    let payMethod: String?
    let channel: String?
    let pgProvider: String?
    let embPgProvider: String?
    let pgTid: String?
    let pgId: String?
    let escrow: Bool?
    let applyNum: String?
    let bankCode: String?
    let bankName: String?
    let cardCode: String?
    let cardName: String?
    let cardIssuerCode: String?
    let cardIssuerName: String?
    let cardPublisherCode: String?
    let cardPublisherName: String?
    let cardQuota: Int?
    let cardNumber: String?
    let cardType: Int?
    let vbankCode: String?
    let vbankName: String?
    let vbankNum: String?
    let vbankHolder: String?
    let vbankDate: Int?
    let vbankIssuedAt: Int?
    let name: String?
    let amount: Int?
    let currency: String?
    let buyerName: String?
    let buyerEmail: String?
    let buyerTel: String?
    let buyerAddr: String?
    let buyerPostcode: String?
    let customData: String?
    let userAgent: String?
    let status: String?
    let startedAt: String?
    let paidAt: String?
    let receiptUrl: String?
    let createdAt: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case impUid = "imp_uid"
        case merchantUid = "merchant_uid"
        case payMethod = "pay_method"
        case channel
        case pgProvider = "pg_provider"
        case embPgProvider = "emb_pg_provider"
        case pgTid = "pg_tid"
        case pgId = "pg_id"
        case escrow
        case applyNum = "apply_num"
        case bankCode = "bank_code"
        case bankName = "bank_name"
        case cardCode = "card_code"
        case cardName = "card_name"
        case cardIssuerCode = "card_issuer_code"
        case cardIssuerName = "card_issuer_name"
        case cardPublisherCode = "card_publisher_code"
        case cardPublisherName = "card_publisher_name"
        case cardQuota = "card_quota"
        case cardNumber = "card_number"
        case cardType = "card_type"
        case vbankCode = "vbank_code"
        case vbankName = "vbank_name"
        case vbankNum = "vbank_num"
        case vbankHolder = "vbank_holder"
        case vbankDate = "vbank_date"
        case vbankIssuedAt = "vbank_issued_at"
        case name, amount, currency
        case buyerName = "buyer_name"
        case buyerEmail = "buyer_email"
        case buyerTel = "buyer_tel"
        case buyerAddr = "buyer_addr"
        case buyerPostcode = "buyer_postcode"
        case customData = "custom_data"
        case userAgent = "user_agent"
        case status, startedAt, paidAt
        case receiptUrl = "receipt_url"
        case createdAt, updatedAt
    }
}

// MARK: - Request DTOs

nonisolated struct OrderCreateRequestDTO: Encodable, Sendable {
    let filterId: String
    let totalPrice: Int

    enum CodingKeys: String, CodingKey {
        case filterId = "filter_id"
        case totalPrice = "total_price"
    }
}

nonisolated struct PaymentValidationRequestDTO: Encodable, Sendable {
    let impUid: String

    enum CodingKeys: String, CodingKey {
        case impUid = "imp_uid"
    }
}
