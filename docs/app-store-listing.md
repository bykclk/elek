# App Store listing — Elek (draft)

> Fill these into App Store Connect. "Elek" alone may be taken; if so use the
> fallback name. Character limits noted.

## Name (max 30)
- Primary: **Elek**
- Fallback: **Elek – Reklam Engelleyici**

## Subtitle (max 30)
Reklam ve izleyici engelleyici

## Promotional text (max 170, editable anytime)
Cihazında, sistem genelinde reklam ve izleyici engelle. Hesap yok, reklam yok,
veri toplama yok — sadece daha hızlı ve daha temiz bir internet.

## Description
Elek, iPhone'unda reklamları ve izleyicileri DNS düzeyinde, sistem genelinde
engelleyen bir gizlilik aracıdır. Tek bir uygulamada değil; tüm uygulamalarda ve
Safari'de çalışır.

Nasıl çalışır?
Elek, cihazının yaptığı alan adı (DNS) sorgularını cihaz üzerinde inceler.
Reklam ve izleyici alanlarını yerel olarak engeller; geri kalan sorguları şifreli
DNS-over-HTTPS ile çözer. Hiçbir trafik geliştiriciye gitmez.

• Sistem genelinde — her uygulamada ve tarayıcıda çalışır
• Cihazda çalışır — engelleme kararları telefonunda verilir
• Şifreli — izin verilen sorgular DNS-over-HTTPS ile çözülür
• Şeffaf — bugün engellenen istek sayısını gör
• Gizlilik dostu — hesap yok, reklam yok, takip yok, veri toplama yok
• Tek dokunuş — büyük düğmeyle aç/kapat

Elek senin verini toplamaz, saklamaz, satmaz. Gizlilik uygulamanın bütün amacı.

Not: Elek bir Ağ Uzantısı (DNS Proxy) kullanır; ilk açtığında bir sistem izni
ister. Engelleme listesi açık kaynaklı bir listeden cihazına indirilir.

## Keywords (max 100, comma-separated, no spaces)
reklam engelleyici,adblock,izleyici,gizlilik,dns,takip engelleme,reklam,engelle,güvenlik,hızlandır

## Support URL
https://github.com/<kullanıcı>/elek  (veya bir destek sayfası)

## Marketing URL (optional)
(boş bırakılabilir)

## Privacy Policy URL
https://<kullanıcı>.github.io/elek/privacy-policy  (docs/privacy-policy.md'yi yayınla)

## Category
- Primary: Utilities
- Secondary: Productivity

## Age rating
4+ (reklam yok, kullanıcı üretimi içerik yok)

## App Privacy (nutrition label answers)
- Data collection: **No, we do not collect data from this app.**
  (Cihazda işlenen DNS geliştiriciye gönderilmez; izin verilen sorgular
  Cloudflare'a DoH ile gider ama bizim tarafımızdan toplanmaz.)

## App Review Information
- Sign-in required: No
- Notes: docs/app-review-notes.md içeriğini yapıştır (gizlilik politikası URL'sini ekle).
- Contact: omerbuyukcelik@gmail.com

## Export compliance
- Uses encryption: Yes, but only standard HTTPS/TLS (DNS-over-HTTPS).
  Genelde "exempt" — App Store Connect'te "yalnızca standart şifreleme"
  şıkkını seçersen ek belge istemez.
