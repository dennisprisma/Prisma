import Foundation

/// Lo shader Metal dello sfondo d'acqua, portato dal prototipo approvato (anteprima-sfondo.html).
/// È una stringa compilata a runtime con `makeLibrary(source:options:)`: SwiftPM da riga di
/// comando non compila i file .metal.
///
/// Acqua vista dall'alto: uno specchio argento che riflette uno studio morbido, con un velo
/// trasparente sul fondo. Le misure sono in punti (come i px CSS del prototipo).
enum ShaderAcqua {
    /// Quanti impatti, perline e conche lo shader legge al massimo (uguali al prototipo).
    static let maxImpatti = 20
    static let maxPerline = 8
    static let maxConche = 4

    /// Disposizione delle uniformi in float (tutti float4: nessun riempimento tra Swift e MSL).
    enum Strato {
        static let impatti = 0        // 20 × (x, y, raggio raggiunto, riga nella tabella)
        static let perline = 80       // 8 × (x, y, quota, raggio)
        static let conche = 112       // 4 × (x, y, raggio, profondità)
        static let concheB = 128      // 4 × (seme, bordo, -, -)
        static let camera = 144       // (x, y, z, tempo)
        static let cielo1 = 148
        static let cielo2 = 152
        static let cielo3 = 156
        static let risoluzione = 160  // (larghezza, altezza, punti per pixel, scuro)
        static let conti = 164        // (impatti, perline, conche, -)
        static let totale = 168
    }

    static let sorgente = #"""
#include <metal_stdlib>
using namespace metal;

#define MAXI 20
#define MAXP 8
#define MAXC 4
#define NRI 1024

struct Uniformi {
  float4 imp[MAXI];   // x, y, raggio raggiunto, riga nella tabella
  float4 per[MAXP];   // perline: x, y, quota, raggio
  float4 cra[MAXC];   // conche: x, y, raggio, profondità
  float4 craB[MAXC];  // conche: seme, bordo, -, -
  float4 cam;         // camera (x, y, z) e tempo
  float4 c1;
  float4 c2;
  float4 c3;
  float4 ris;         // larghezza, altezza, punti per pixel, scuro
  float4 conti;       // impatti, perline, conche
};

// Parametri del materiale
constant float F0 = 0.02f;          // riflettanza fisica dell'acqua a picco
constant float SPECCHIO = 0.64f;    // quota di riflesso a picco «da studio»
constant float PROF = 70.0f;        // profondità del fondo (punti)
constant float3 LUCE = float3(-0.14f, -0.20f, 0.97f);
constant float3 LAMPADA = float3(-0.40f, -0.48f, 0.78f);   // lampada piccola, fuori campo: scintille
constant float2 VERSO = float2(-0.56f, -0.83f);            // da dove arriva la luce dello studio

// Il mod di GLSL (sempre positivo)
float modg(float x, float y) { return x - y * floor(x / y); }

// smoothstep anche con i bordi invertiti, come in WebGL
float liscio(float e0, float e1, float x) {
  float t = clamp((x - e0) / (e1 - e0), 0.0f, 1.0f);
  return t * t * (3.0f - 2.0f * t);
}

// Gradiente del tema (come il fondo CSS a 160°)
float3 gradiente(float2 p, constant Uniformi &u) {
  float2 dir = float2(0.342f, 0.940f);
  float2 R = u.ris.xy;
  float t = dot(p - R * 0.5f, dir) / (abs(R.x * dir.x) + abs(R.y * dir.y)) + 0.5f;
  t = clamp(t, 0.0f, 1.0f);
  float3 c1 = u.c1.xyz;
  float3 c2 = u.c2.xyz;
  float3 c3 = u.c3.xyz;
  return t < 0.55f ? mix(c1, c2, t / 0.55f) : mix(c2, c3, (t - 0.55f) / 0.45f);
}

// Lo studio sopra l'acqua: soffitto diffusore con una grande sorgente sfumata.
// o = punto riflettente, d = raggio riflesso. Per l'acqua piatta ridà il gradiente del tema.
float3 studio(float3 o, float3 d, constant Uniformi &u, bool scuro) {
  float dz = max(d.z, 0.0f);
  float lato = 0.5f + 0.5f * dot(normalize(d.xy + 1e-4f), normalize(VERSO));
  float3 parete = scuro ? float3(0.012f, 0.03f, 0.05f) + float3(0.10f, 0.15f, 0.20f) * lato * lato
                        : float3(0.30f, 0.32f, 0.34f) + float3(0.40f) * lato * lato;
  if (dz < 0.02f) return parete;
  float3 cam = u.cam.xyz;
  float2 R = u.ris.xy;
  float2 c = o.xy + d.xy * ((cam.z - o.z) / dz);    // punto colpito sul soffitto
  float2 q0 = (c + cam.xy) * 0.5f;                  // dove apparirebbe con l'acqua piatta
  float2 s = q0 / R;
  float3 g = gradiente(q0, u);
  float3 base = scuro ? g : g * 0.96f + float3(0.03f - 0.07f * s.y);
  // grande sorgente morbida in alto a sinistra: un'ellisse sfumata, senza spigoli
  float2 q = (s - float2(0.24f, 0.10f)) * float2(R.x / R.y, 1.0f) / float2(0.42f, 0.22f);
  float box = exp(-1.6f * dot(q, q));
  // una striscia lunga e debole in basso a destra
  float2 q2 = (s - float2(0.82f, 0.88f)) * float2(R.x / R.y, 1.0f) / float2(0.55f, 0.10f);
  float st = exp(-2.0f * dot(q2, q2));
  float3 col = scuro ? base * 0.9f + float3(0.30f, 0.38f, 0.46f) * box + float3(0.06f, 0.09f, 0.12f) * st
                     : base * 0.93f + float3(0.11f, 0.108f, 0.105f) * box + float3(0.04f) * st;
  return mix(parete, col, smoothstep(0.05f, 0.5f, dz));
}

// Le luci dello studio viste attraverso l'inclinazione dello specchio.
// e = di quanto il riflesso devia rispetto all'acqua piatta (circa due volte la pendenza).
float lobo(float phi, float c, float w) {
  float d = abs(modg(phi - c + 3.14159265f, 6.2831853f) - 3.14159265f);
  return exp(-d * d / (w * w));
}
float3 luci(float2 e, bool scuro) {
  float m = length(e);
  float phi = atan2(e.y, e.x);
  float lampade = clamp(lobo(phi, -2.16f, 0.85f) + 0.6f * lobo(phi, 0.25f, 0.48f) + 0.35f * lobo(phi, 1.9f, 0.42f), 0.0f, 1.0f);
  float corona = smoothstep(0.018f, 0.08f, m) * (1.0f - smoothstep(0.10f, 0.22f, m));   // la corona dei pannelli
  float oltre = smoothstep(0.14f, 0.25f, m) * (1.0f - smoothstep(0.42f, 1.2f, m));      // il soffitto più in là
  float finestra = lobo(phi, -2.16f, 0.45f) * oltre;                                   // una finestra chiara dal lato della luce
  float pareti = smoothstep(0.4f, 1.2f, m);                                             // pendenze ripide: le pareti
  float qa = (m - 0.10f) / 0.05f;
  float anello = exp(-qa * qa);
  float a = clamp(dot(e, normalize(VERSO)) / 0.06f, -1.0f, 1.0f);                       // pendenze piccolissime
  if (scuro)
    return float3(0.03f, 0.04f, 0.05f) * a + corona * (float3(0.17f, 0.21f, 0.25f) * lampade - float3(0.02f, 0.03f, 0.04f) * (1.0f - lampade))
         + float3(0.06f, 0.08f, 0.10f) * anello - float3(0.03f, 0.04f, 0.05f) * oltre + float3(0.12f, 0.15f, 0.18f) * finestra
         - float3(0.05f, 0.07f, 0.09f) * pareti;
  return float3(0.025f) * a + corona * (float3(0.15f) * lampade - float3(0.15f, 0.145f, 0.14f) * (1.0f - lampade))
       - float3(0.13f, 0.125f, 0.12f) * oltre + float3(0.14f) * finestra - float3(0.20f) * pareti;
}

// Profilo a mano della conca (non lineare): fondo piatto, pareti ripide, bordo rialzato e irregolare
float conca(float2 d, float4 cr, float4 cb) {
  float r = length(d);
  float th = atan2(d.y, d.x);
  float R = cr.z * (1.0f + 0.03f * sin(2.0f * th + cb.x) + 0.02f * sin(3.0f * th + 2.3f * cb.x) + 0.008f * sin(7.0f * th + 4.1f * cb.x));
  float x = r / R;
  float x2 = x * x;
  float bordo = (x - 1.12f) / 0.30f;
  return cr.w * (-exp(-x2 * x2) + cb.y * exp(-bordo * bordo));
}

// Pendenza e laplaciano dell'acqua nel punto p (somma degli impatti + conche + mare lungo)
float3 campo(float2 p, constant Uniformi &u, device const float2 *prof) {
  float2 g = float2(0.0f);
  float lap = 0.0f;
  int nImp = int(u.conti.x);
  for (int i = 0; i < MAXI; i++) {
    if (i >= nImp) break;
    float4 im = u.imp[i];
    float2 d = p - im.xy;
    float r2 = dot(d, d);
    if (r2 >= im.z * im.z) continue;
    float r = sqrt(r2);
    // interpolazione lineare tra due campioni del profilo (come il filtro della texture)
    int i0 = min(int(r), NRI - 2);
    float fr = r - float(i0);
    int b = int(im.w) * NRI + i0;
    float2 s0 = prof[b];
    float2 s1 = prof[b + 1];
    float2 s = mix(s0, s1, fr);
    g += d * (s.x / max(r, 1e-3f));
    lap += s.y;
  }
  int nCra = int(u.conti.z);
  for (int i = 0; i < MAXC; i++) {
    if (i >= nCra) break;
    float4 cr = u.cra[i];
    float4 cb = u.craB[i];
    float2 d = p - cr.xy;
    if (dot(d, d) > cr.z * cr.z * 4.0f) continue;
    const float E = 0.75f;
    float hx1 = conca(d + float2(E, 0.0f), cr, cb);
    float hx0 = conca(d - float2(E, 0.0f), cr, cb);
    float hy1 = conca(d + float2(0.0f, E), cr, cb);
    float hy0 = conca(d - float2(0.0f, E), cr, cb);
    g += float2(hx1 - hx0, hy1 - hy0) / (2.0f * E);
  }
  // mare lungo appena percettibile: lo specchio non è mai perfettamente fermo
  float tempo = u.cam.w;
  float2 k1 = float2(0.0105f, 0.0042f);
  float2 k2 = float2(-0.0051f, 0.0093f);
  float a1 = 0.0065f;
  float a2 = 0.0045f;
  float p1 = dot(k1, p) - tempo * 0.42f;
  float p2 = dot(k2, p) - tempo * 0.35f + 1.7f;
  g += k1 * (a1 * 60.0f * cos(p1)) + k2 * (a2 * 60.0f * cos(p2));
  lap -= dot(k1, k1) * a1 * 60.0f * sin(p1) + dot(k2, k2) * a2 * 60.0f * sin(p2);
  return float3(g, lap);
}

// Ombra e fuoco delle perline sul fondo
float ombre(float2 b, constant Uniformi &u) {
  float o = 1.0f;
  int nPer = int(u.conti.y);
  for (int j = 0; j < MAXP; j++) {
    if (j >= nPer) break;
    float4 pe = u.per[j];
    float2 c = pe.xy - LUCE.xy / LUCE.z * (pe.z + PROF);
    float d = length(b - c);
    float R = max(pe.w, 0.5f);
    o *= 1.0f - 0.22f * liscio(R * 1.6f, R * 0.4f, d);
    o += 0.5f * exp(-d * d / (R * R * 0.08f));
  }
  return o;
}

// Colore dell'acqua nel punto p visto lungo la direzione v
float3 acqua(float2 p, float3 v, constant Uniformi &u, device const float2 *prof, bool scuro) {
  float3 f = campo(p, u, prof);
  float2 g = f.xy;
  float gl = length(g);
  g *= 1.0f / (1.0f + gl * 0.25f);   // le pareti ripide si comprimono dolcemente
  float3 n = normalize(float3(-g, 1.0f));
  float c = clamp(-dot(v, n), 0.0f, 1.0f);
  float F = F0 + (1.0f - F0) * pow(1.0f - c, 5.0f);
  float3 r = reflect(v, n);
  float3 r0 = float3(v.xy, -v.z);
  float2 e = r.xy / max(r.z, 0.08f) - r0.xy / r0.z;
  float3 rif = studio(float3(p, 0.0f), r, u, scuro) + luci(e, scuro);
  // velo trasparente: si vede il fondo, spostato dalla rifrazione e acceso dalle caustiche
  float3 t = refract(v, n, 0.75f);
  float2 b = p + t.xy * (PROF / max(-t.z, 0.3f));
  float ca = 1.0f - (scuro ? 0.6f : 0.32f) * tanh(clamp(PROF * 0.25f * f.z, -10.0f, 10.0f));
  ca = mix(ca, 1.0f, smoothstep(0.25f, 0.9f, gl));   // dove l'acqua è ripida la luce si sparpaglia
  float3 gb = gradiente(b, u);
  float3 fondo = scuro ? gb * 0.9f : mix(gb, float3(0.88f), 0.3f);
  fondo *= ca * ombre(b, u);
  float spec = mix(SPECCHIO, 1.0f, (F - F0) / (1.0f - F0));
  float3 col = mix(fondo, rif, spec);
  // scintille: il riflesso della lampada sui fianchi delle onde
  float sp = pow(max(dot(r, LAMPADA), 0.0f), 900.0f);
  return col + sp * (scuro ? 0.9f : 0.6f);
}

// Spalla morbida: le luci forti non si bruciano
float3 tono(float3 x) {
  float3 s = float3(0.86f) + 0.14f * (float3(1.0f) - exp(-(x - float3(0.86f)) / 0.14f));
  return select(max(x, float3(0.0f)), s, x >= float3(0.86f));
}

float rumore(float2 q) { return fract(sin(dot(q, float2(12.9898f, 78.233f))) * 43758.5453f); }

// Un triangolo solo che copre tutto lo schermo
vertex float4 vs_acqua(uint vid [[vertex_id]]) {
  float2 p = float2(vid == 1 ? 3.0f : -1.0f, vid == 2 ? 3.0f : -1.0f);
  return float4(p, 0.0f, 1.0f);
}

fragment float4 fs_acqua(float4 pos [[position]],
                         constant Uniformi &u [[buffer(0)]],
                         device const float2 *prof [[buffer(1)]]) {
  float dpr = u.ris.z;
  float2 p = pos.xy / dpr;   // origine in alto a sinistra, in punti
  float3 cam = u.cam.xyz;
  bool scuro = u.ris.w > 0.5f;
  float3 v = normalize(float3(p, 0.0f) - cam);
  float3 col = acqua(p, v, u, prof, scuro);
  // perline (goccia che cade, getto): sfere d'acqua che riflettono lo studio e rifrangono l'acqua sotto
  int nPer = int(u.conti.y);
  for (int j = 0; j < MAXP; j++) {
    if (j >= nPer) break;
    float4 pe = u.per[j];
    float R = pe.w;
    if (R < 0.3f) continue;
    float3 C = float3(pe.xy, pe.z);
    float3 oc = cam - C;
    float bb = dot(oc, v);
    float dist = sqrt(max(dot(oc, oc) - bb * bb, 0.0f));
    float px = 1.0f / dpr;
    float m = 1.0f - smoothstep(R - px, R + px * 0.5f, dist);
    if (m <= 0.0f) continue;
    float hh = sqrt(max(R * R - dist * dist, 0.0f));
    float3 hit = cam + v * (-bb - hh);
    float3 n1 = normalize(hit - C);
    float c1 = clamp(-dot(v, n1), 0.0f, 1.0f);
    float F1 = F0 + (1.0f - F0) * pow(1.0f - c1, 5.0f);
    float3 rif = studio(hit, reflect(v, n1), u, scuro);
    float3 t1 = refract(v, n1, 0.75f);
    float3 e = hit + t1 * (-2.0f * dot(hit - C, t1));
    float3 n2 = normalize(e - C);
    float3 t2 = refract(t1, -n2, 1.333f);
    if (dot(t2, t2) < 0.5f) t2 = reflect(t1, -n2);
    float3 dietro = t2.z < -0.02f ? acqua(e.xy + t2.xy * (-e.z / t2.z), t2, u, prof, scuro) : studio(e, t2, u, scuro) * 1.2f;
    // trasparente al centro; verso il bordo riflette lo studio (pareti scure, luce chiara)
    float bordo = clamp((F1 - F0) / (1.0f - F0) * 1.6f, 0.0f, 1.0f);
    float3 pc = mix(dietro * 0.96f, rif * 1.1f, bordo);
    pc += pow(max(dot(reflect(v, n1), LAMPADA), 0.0f), 260.0f) * 1.4f;
    col = mix(col, pc, m);
    break;
  }
  col = tono(col);
  // dithering ±0,5/255: niente scalini nei gradienti
  col += (rumore(pos.xy) - 0.5f) / 255.0f;
  return float4(col, 1.0f);
}
"""#
}
