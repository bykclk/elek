// wrangler embeds *.bin files as binary Data modules (ArrayBuffer) via the
// [[rules]] entry in wrangler.toml.
declare module "*.bin" {
  const data: ArrayBuffer;
  export default data;
}
