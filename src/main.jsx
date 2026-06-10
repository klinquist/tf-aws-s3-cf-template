import React from "react";
import { createRoot } from "react-dom/client";
import "./styles.css";

function App() {
  return (
    <main className="shell">
      <section className="hero">
        <div className="hero-copy">
          <p className="eyebrow">S3 + CloudFront + Route53</p>
          <h1>Launch a fast React site on your own AWS account.</h1>
          <p className="lede">
            This starter builds with Vite, deploys through GitHub Actions, and
            serves globally from CloudFront with HTTPS.
          </p>
          <div className="actions" aria-label="Primary links">
            <a href="https://vite.dev" className="button primary">
              Vite docs
            </a>
            <a href="https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Introduction.html" className="button secondary">
              CloudFront
            </a>
          </div>
        </div>
        <div className="deploy-panel" aria-label="Deployment pipeline">
          <div className="pipeline-step">
            <span>1</span>
            <div>
              <strong>Commit</strong>
              <p>Push changes to the main branch.</p>
            </div>
          </div>
          <div className="pipeline-step">
            <span>2</span>
            <div>
              <strong>Build</strong>
              <p>GitHub Actions runs npm ci and npm run build.</p>
            </div>
          </div>
          <div className="pipeline-step">
            <span>3</span>
            <div>
              <strong>Deploy</strong>
              <p>The dist folder syncs to S3 and invalidates CloudFront.</p>
            </div>
          </div>
        </div>
      </section>
      <section className="features" aria-label="Included features">
        <article>
          <h2>Infrastructure as code</h2>
          <p>Terraform owns the S3 bucket, CDN, certificate, and DNS records.</p>
        </article>
        <article>
          <h2>Simple local workflow</h2>
          <p>Use npm run dev locally, then push to deploy the production build.</p>
        </article>
        <article>
          <h2>Low monthly cost</h2>
          <p>Static assets stay inexpensive while CloudFront handles global delivery.</p>
        </article>
      </section>
    </main>
  );
}

createRoot(document.getElementById("root")).render(<App />);
