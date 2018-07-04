use "buffered"

type MtpTransportProtocol is (MtpTcpAbridged | MtpTcpIntermediate)

primitive MtpTcpAbridged
  fun apply(data: Bytes): Bytes =>
    data

primitive MtpTcpIntermediate
  fun apply(data: Bytes): Bytes =>
    let reader = Reader.>append(data)
    try
      let length = reader.u32_le()?
      let padding = length % 4
      if padding != 0 then
        let without_len_bytes = recover val reader.block(USize.from[U32](length))? end

        let without_padding = recover val
          without_len_bytes.slice(0, USize.from[U32](length - padding))
        end

        let without_padding_len = U32.from[USize](without_padding.size())

        recover
          Util.u32_le_to_buffer(without_padding_len)
            .>append(without_padding)
        end
      else
        data
      end
    else recover val Bytes end end
