# Elek — Gizlilik Politikası

**Yürürlük tarihi:** 30 Haziran 2026

Elek, cihaz üzerinde DNS filtrelemesiyle reklamları ve izleyicileri sistem
genelinde engelleyen bir iOS uygulamasıdır. Gizliliğin uygulamanın bütün amacı
olması nedeniyle politika kısadır: **Elek hiçbir kişisel veriyi toplamaz,
saklamaz, satmaz veya paylaşmaz.** Hesap yok, analitik yok, reklam yok, izleme
yok.

## Elek nasıl çalışır ve verilerinize ne olur

- **DNS sorguları cihazınızda işlenir.** Koruma açıkken Elek, cihazınızın
  baktığı alan adlarını inceler ve her birini engelleyip engellemeyeceğine karar
  verir. Bu karar tamamen cihazınızda verilir.
- **Filtre, yerel bir VPN yapılandırması olarak çalışır.** iOS, Elek'i VPN
  olarak gösterir çünkü uygulamaların cihaz üzerinde DNS filtrelemesi yapmasının
  mekanizması budur. Elek'in tünelinin sunucusu yoktur: tünele yalnızca DNS
  sorguları girer, bunlar cihazınızda işlenir ve başka hiçbir trafik bu tünelden
  geçmez.
- **Engellenen sorgular cihazınızdan çıkmaz.** Bir alan adı engelleme
  listesindeyse Elek ona yerel olarak (`NXDOMAIN` yanıtıyla) cevap verir. Hiçbir
  yere bir şey gönderilmez.
- **İzin verilen sorgular şifreli iletilir.** Engellenmeyen alan adları,
  şifreli DNS-over-HTTPS (`https://1.1.1.1/dns-query`) üzerinden Cloudflare'a
  iletilerek çözülür. Bu sorgular
  [Cloudflare'ın gizlilik politikası](https://www.cloudflare.com/privacypolicy/)
  kapsamında işlenir. Elek geliştiricisi bunları görmez, kaydetmez, saklamaz.
- **Engelleme listesi cihazınıza indirilir.** Elek, herkese açık bir alan adı
  listesini ([HaGeZi listesi](https://github.com/hagezi/dns-blocklists))
  doğrudan kaynağından cihazınıza indirir ve yerel olarak derler. Bu istek bize
  değil, o kaynağa gider.
- **"Bugün engellenen" sayacı yereldir.** Uygulamada görünen sayı yalnızca
  cihazınızda (uygulamanın App Group alanında) saklanır ve hiçbir zaman
  iletilmez.

## Topladığımız veriler

Hiçbiri. Elek kişisel veri, reklam tanımlayıcısı, iletişim bilgisi, konum veya
kullanım analitiği toplamaz. Üçüncü taraf analitik, reklam veya çökme-raporlama
SDK'sı içermez. Elek sizi uygulamalar veya web siteleri arasında izlemez.

## Üçüncü taraf hizmetler

- **Cloudflare** — izin verilen sorgular için şifreli DNS (DoH) çözücü.
- **HaGeZi listesi (GitHub üzerinden)** — cihazınızın indirdiği engelleme
  listesinin kaynağı.

Elek'in kendi sunucusu yoktur ve geliştiricisine hiçbir veri göndermez.

## Çocuklar

Elek çocuklara yönelik değildir ve hiç kimseden veri toplamaz.

## Değişiklikler

Bu politika değişirse, güncel sürüm yeni yürürlük tarihiyle burada yayımlanır.

## İletişim

Sorular: **omerbuyukcelik@gmail.com**
