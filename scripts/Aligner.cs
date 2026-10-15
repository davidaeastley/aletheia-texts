using System;
using System.Collections.Generic;
using System.Text;

// Aligns the verses of one book of a translation to the verses of a reference (the KJV).
// Both are given in reading order. Chapter/verse numbers are only a hint: the alignment
// is driven by how alike the texts are (character trigrams, so differences in old spelling
// do not matter much) and by verse length, and it allows a verse to be merged or split.
public static class Aligner
{
    static string Norm(string s)
    {
        var sb = new StringBuilder();
        string d = s.ToLowerInvariant().Normalize(NormalizationForm.FormD);
        bool space = true;
        foreach (char c0 in d)
        {
            char c = c0;
            if (c >= 0x300 && c <= 0x36f) continue;
            if (c == 'æ') { sb.Append("ae"); space = false; continue; }
            if (c == 'v') c = 'u'; else if (c == 'j') c = 'i'; else if (c == 'y') c = 'i'; else if (c == 'w') c = 'u';
            if (c >= 'a' && c <= 'z' || c >= '0' && c <= '9') { sb.Append(c); space = false; }
            else if (!space) { sb.Append(' '); space = true; }
        }
        return sb.ToString().Trim();
    }
    public static double OpPenalty = 0;   // extra cost of any merge/split/gap: for a source in another language, where the sequence is normally verse for verse
    public static double KeyBonus = 0.15;   // cost taken off when a verse pair already has the same chapter:verse number
    public static bool UseIdf = false;   // for two different languages: rare trigrams (names, numbers, cognates) count more than common ones
    [ThreadStatic] static Dictionary<int, int> weights;
    static Dictionary<int, int> Grams(string n)
    {
        var d = new Dictionary<int, int>();
        string t = " " + n + " ";
        for (int i = 0; i + 3 <= t.Length; i++)
        {
            int k = (t[i] << 16) ^ (t[i + 1] << 8) ^ t[i + 2] ^ (t[i] * 31);
            int w = 1; if (weights != null) weights.TryGetValue(k, out w); if (w < 1) w = 1;
            int v; d.TryGetValue(k, out v); d[k] = v + w;
        }
        return d;
    }
    static void BuildWeights(string[] a, string[] b)
    {
        var df = new Dictionary<int, int>(); int docs = 0;
        foreach (var arr in new[] { a, b })
            foreach (var s in arr)
            {
                docs++; var seen = new HashSet<int>(); string t = " " + Norm(s) + " ";
                for (int i = 0; i + 3 <= t.Length; i++) seen.Add((t[i] << 16) ^ (t[i + 1] << 8) ^ t[i + 2] ^ (t[i] * 31));
                foreach (int k in seen) { int v; df.TryGetValue(k, out v); df[k] = v + 1; }
            }
        weights = new Dictionary<int, int>();
        foreach (var kv in df) weights[kv.Key] = Math.Max(1, (int)Math.Round(3 * Math.Log(1.0 + (double)docs / kv.Value)));
    }
    static Dictionary<int, int> Merge(Dictionary<int, int> a, Dictionary<int, int> b)
    {
        var d = new Dictionary<int, int>(a);
        foreach (var kv in b) { int v; d.TryGetValue(kv.Key, out v); d[kv.Key] = v + kv.Value; }
        return d;
    }
    static int Total(Dictionary<int, int> d) { int t = 0; foreach (var kv in d) t += kv.Value; return t; }
    static double Dice(Dictionary<int, int> a, int ta, Dictionary<int, int> b, int tb)
    {
        if (ta + tb == 0) return 0;
        var small = a.Count <= b.Count ? a : b; var big = a.Count <= b.Count ? b : a;
        int inter = 0;
        foreach (var kv in small) { int v; if (big.TryGetValue(kv.Key, out v)) inter += Math.Min(kv.Value, v); }
        return 2.0 * inter / (ta + tb);
    }
    class Side
    {
        public Dictionary<int, int>[][] g = new Dictionary<int, int>[4][];   // g[n][i] = grams of verses i..i+n-1 merged
        public int[][] t = new int[4][];
        public int[] len;
        public Side(string[] texts)
        {
            int n = texts.Length; len = new int[n];
            for (int k = 1; k <= 3; k++) { g[k] = new Dictionary<int, int>[n]; t[k] = new int[n]; }
            for (int i = 0; i < n; i++)
            {
                string nn = Norm(texts[i]); len[i] = nn.Length;
                g[1][i] = Grams(nn); t[1][i] = Total(g[1][i]);
            }
            for (int i = 0; i + 1 < n; i++) { g[2][i] = Merge(g[1][i], g[1][i + 1]); t[2][i] = t[1][i] + t[1][i + 1]; }
            for (int i = 0; i + 2 < n; i++) { g[3][i] = Merge(g[2][i], g[1][i + 2]); t[3][i] = t[2][i] + t[1][i + 2]; }
        }
        public int Len(int i, int n) { int s = 0; for (int k = 0; k < n; k++) s += len[i + k]; return s; }
    }
    static readonly int[][] Ops = new int[][] { new[] {1,1,0}, new[] {1,2,0}, new[] {2,1,0}, new[] {2,2,0}, new[] {1,3,0}, new[] {3,1,0}, new[] {1,0,0}, new[] {0,1,0}, new[] {2,2,1} };   // last = two neighbouring verses in swapped order
    const double Gap = 0.8;
    static double Pair(Side S, int i, Side R, int j)
    {
        double sim = Dice(S.g[1][i], S.t[1][i], R.g[1][j], R.t[1][j]);
        double lp = Math.Min(1.0, Math.Abs(Math.Log((S.len[i] + 10.0) / (R.len[j] + 10.0))));
        return 0.7 * (1 - sim) + 0.3 * lp;
    }

    // returns rows of {sStart, sCount, rStart, rCount}
    public static int[][] Align(string[] sKeys, string[] sText, string[] rKeys, string[] rText)
    {
        int N = sText.Length, M = rText.Length;
        weights = null; if (UseIdf) BuildWeights(sText, rText);
        var S = new Side(sText); var R = new Side(rText);
        int W = Math.Max(80, Math.Max(N, M) / 8);
        int width = 2 * W + 1;
        double[][] dp = new double[N + 1][]; sbyte[][] bk = new sbyte[N + 1][];
        for (int i = 0; i <= N; i++) { dp[i] = new double[width]; bk[i] = new sbyte[width]; for (int k = 0; k < width; k++) dp[i][k] = double.MaxValue; }
        Func<int, int> center = i => N == 0 ? 0 : (int)Math.Round((double)i * M / N);
        Func<int, int, int> col = (i, j) => j - center(i) + W;
        dp[0][col(0, 0)] = 0;
        for (int i = 0; i <= N; i++)
        {
            int c = center(i);
            for (int j = Math.Max(0, c - W); j <= Math.Min(M, c + W); j++)
            {
                int cj = col(i, j); double cur = dp[i][cj];
                if (cur == double.MaxValue) continue;
                for (int o = 0; o < Ops.Length; o++)
                {
                    int p = Ops[o][0], q = Ops[o][1], cr = Ops[o][2]; int ni = i + p, nj = j + q;
                    if (ni > N || nj > M) continue;
                    int cn = col(ni, nj); if (cn < 0 || cn >= width) continue;
                    double cost;
                    if (p == 0 || q == 0) cost = Gap * (p + q) + OpPenalty;
                    else if (cr == 1)
                    {
                        double c1 = Pair(S, i, R, j + 1), c2 = Pair(S, i + 1, R, j);
                        cost = UseIdf ? 99 : c1 + c2 + 0.12;   // swapped neighbours only happen in the Vulgate order, never when the source is another language
                    }
                    else
                    {
                        double sim = Dice(S.g[p][i], S.t[p][i], R.g[q][j], R.t[q][j]);
                        int ls = S.Len(i, p), lr = R.Len(j, q);
                        double lp = Math.Min(1.0, Math.Abs(Math.Log((ls + 10.0) / (lr + 10.0))));
                        cost = (0.7 * (1 - sim) + 0.3 * lp) * (p + q) / 2.0;
                        if (p + q > 2) cost += 0.08;
                        if (p != 1 || q != 1) cost += OpPenalty;
                        if (p == 1 && q == 1 && sKeys[i] == rKeys[j]) cost = Math.Max(0, cost - KeyBonus);
                    }
                    double v = cur + cost;
                    if (v < dp[ni][cn]) { dp[ni][cn] = v; bk[ni][cn] = (sbyte)o; }
                }
            }
        }
        var rows = new List<int[]>();
        int bi = N, bj = M;
        if (dp[N][col(N, M)] == double.MaxValue) throw new Exception("no alignment path (band too narrow)");
        while (bi > 0 || bj > 0)
        {
            int o = bk[bi][col(bi, bj)]; int p = Ops[o][0], q = Ops[o][1];
            bi -= p; bj -= q; rows.Add(new[] { bi, p, bj, q, Ops[o][2] });
        }
        rows.Reverse();
        return rows.ToArray();
    }
}
