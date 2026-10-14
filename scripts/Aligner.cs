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
    static Dictionary<int, int> Grams(string n)
    {
        var d = new Dictionary<int, int>();
        string t = " " + n + " ";
        for (int i = 0; i + 3 <= t.Length; i++)
        {
            int k = (t[i] << 16) ^ (t[i + 1] << 8) ^ t[i + 2] ^ (t[i] * 31);
            int v; d.TryGetValue(k, out v); d[k] = v + 1;
        }
        return d;
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
    static readonly int[][] Ops = new int[][] { new[] {1,1}, new[] {1,2}, new[] {2,1}, new[] {2,2}, new[] {1,3}, new[] {3,1}, new[] {1,0}, new[] {0,1} };
    const double Gap = 0.8;

    // returns rows of {sStart, sCount, rStart, rCount}
    public static int[][] Align(string[] sKeys, string[] sText, string[] rKeys, string[] rText)
    {
        int N = sText.Length, M = rText.Length;
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
                    int p = Ops[o][0], q = Ops[o][1]; int ni = i + p, nj = j + q;
                    if (ni > N || nj > M) continue;
                    int cn = col(ni, nj); if (cn < 0 || cn >= width) continue;
                    double cost;
                    if (p == 0 || q == 0) cost = Gap * (p + q);
                    else
                    {
                        double sim = Dice(S.g[p][i], S.t[p][i], R.g[q][j], R.t[q][j]);
                        int ls = S.Len(i, p), lr = R.Len(j, q);
                        double lp = Math.Min(1.0, Math.Abs(Math.Log((ls + 10.0) / (lr + 10.0))));
                        cost = (0.7 * (1 - sim) + 0.3 * lp) * (p + q) / 2.0;
                        if (p + q > 2) cost += 0.08;
                        if (p == 1 && q == 1 && sKeys[i] == rKeys[j]) cost = Math.Max(0, cost - 0.15);
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
            bi -= p; bj -= q; rows.Add(new[] { bi, p, bj, q });
        }
        rows.Reverse();
        return rows.ToArray();
    }
}
