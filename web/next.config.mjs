/** @type {import('next').NextConfig} */
const nextConfig = {
  // The site is fully static — all data is prebuilt JSON in public/data by the
  // R pipeline, so we export a static bundle and Vercel serves it with no server
  // runtime (mirrors the old Quarto _site/ deploy model).
  output: "export",
  images: { unoptimized: true },
  // three.js ships untranspiled ESM that older bundler setups choke on; transpile
  // the 3D stack explicitly so the static export builds cleanly.
  transpilePackages: ["three"],
  reactStrictMode: true,
};

export default nextConfig;
