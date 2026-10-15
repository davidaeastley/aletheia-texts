using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Text;

// Reads a CrossWire SWORD "zText" module (CompressType=ZIP, i.e. zlib) without any SWORD tools.
// A testament is three files: .bzs (block index), .bzz (compressed blocks), .bzv (verse index).
public static class SwordZText
{
    // returns every entry of one testament, in index order, as raw (markup included) text; entry i is null when it is empty
    public static string[] ReadTestament(string folder, string testament /* "ot" or "nt" */)
    {
        byte[] bzs = File.ReadAllBytes(Path.Combine(folder, testament + ".bzs"));
        byte[] bzz = File.ReadAllBytes(Path.Combine(folder, testament + ".bzz"));
        byte[] bzv = File.ReadAllBytes(Path.Combine(folder, testament + ".bzv"));
        int blocks = bzs.Length / 12;
        var cache = new Dictionary<int, byte[]>();
        Func<int, byte[]> block = (n) =>
        {
            byte[] data;
            if (cache.TryGetValue(n, out data)) return data;
            uint off = BitConverter.ToUInt32(bzs, n * 12), size = BitConverter.ToUInt32(bzs, n * 12 + 4), raw = BitConverter.ToUInt32(bzs, n * 12 + 8);
            using (var ms = new MemoryStream(bzz, (int)off + 2, (int)size - 2))   // skip the 2-byte zlib header
            using (var ds = new DeflateStream(ms, CompressionMode.Decompress))
            using (var outp = new MemoryStream())
            {
                ds.CopyTo(outp); data = outp.ToArray();
            }
            cache[n] = data; return data;
        };
        int entries = bzv.Length / 10;
        var result = new string[entries];
        for (int i = 0; i < entries; i++)
        {
            uint b = BitConverter.ToUInt32(bzv, i * 10), start = BitConverter.ToUInt32(bzv, i * 10 + 4); ushort len = BitConverter.ToUInt16(bzv, i * 10 + 8);
            if (len == 0 || b >= blocks) { result[i] = null; continue; }
            byte[] d = block((int)b);
            if (start + len > d.Length) { result[i] = "<<bad range>>"; continue; }
            result[i] = Encoding.UTF8.GetString(d, (int)start, len);
        }
        return result;
    }
    // block number of every verse-index entry (entries of one book share a block when BlockType=BOOK)
    public static int[] BlockOf(string folder, string testament)
    {
        byte[] bzv = File.ReadAllBytes(Path.Combine(folder, testament + ".bzv"));
        var r = new int[bzv.Length / 10];
        for (int i = 0; i < r.Length; i++) r[i] = (int)BitConverter.ToUInt32(bzv, i * 10);
        return r;
    }
}
