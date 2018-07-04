use "collections"
use "buffered"

primitive Util
  // fun print(env: Env, arr: Array[U8] box) =>
  //   for byte in arr.values() do env.out.write([byte]) end

  fun _parseHexDigit (char: U8): U8 val =>
    match char
    | '0' => 0
    | '1' => 1
    | '2' => 2
    | '3' => 3
    | '4' => 4
    | '5' => 5
    | '6' => 6
    | '7' => 7
    | '8' => 8
    | '9' => 9
    | 'a' => 10
    | 'b' => 11
    | 'c' => 12
    | 'd' => 13
    | 'e' => 14
    | 'f' => 15
    else 0 end

  fun fromHex (hex: String): Array[U8] val =>
    recover
      let arr = Array[U8]//(hex.size() / 2)
      for i in Range(0, hex.size(), 2) do
        arr.>push(
          try _parseHexDigit(hex(i + 1)?) else 0 end +
          try 16 * _parseHexDigit(hex(i)?) else 0 end
        )
      else arr end
    end

  fun u32_le_to_buffer (num: U32): Bytes iso^ =>
    recover
      let writer = Writer
      let arr: Bytes ref = Bytes

      writer.u32_le(num)

      for chunk in writer.done().values() do
        arr.append(chunk)
      end

      arr
    end

  // fun byteSeqToArray (seq: ByteSeq): Array[U8] val =>
  //   match seq
  //   | let str: String => str.array()
  //   | let arr: Array[U8] val => arr
  //   end

  // fun unnest[T: Any val](arr: Array[Array[T] val] val): Array[T] val =>
  //   recover val
  //     let out: Array[T] ref = Array[T]
  //     for arr2 in arr.values() do
  //       out.concat(arr2.values())
  //     end
  //     out
  //  end
