import {defineConfig,devices} from "@playwright/test";
export default defineConfig({
 testDir:"./tests/browser",
 testMatch:"**/*.spec.mjs",
 timeout:45_000,
 expect:{timeout:12_000},
 forbidOnly:!!process.env.CI,
 retries:process.env.CI?1:0,
 workers:process.env.CI?2:undefined,
 reporter:[["list"],["html",{outputFolder:"site-qualification/playwright-report",open:"never"}]],
 outputDir:"site-qualification/playwright-results",
 use:{baseURL:"http://127.0.0.1:8765",trace:"retain-on-failure",screenshot:"only-on-failure",
      ...devices["Desktop Chrome"]},
 webServer:{command:"python3 -m http.server 8765 --directory site --bind 127.0.0.1",
            url:"http://127.0.0.1:8765/research-geometry.html",reuseExistingServer:!process.env.CI,timeout:30_000}
});
