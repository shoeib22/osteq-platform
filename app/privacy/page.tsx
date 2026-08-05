import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Privacy Policy — Osteq",
};

export default function PrivacyPolicyPage() {
  return (
    <main className="mx-auto max-w-2xl px-6 py-16 text-neutral-800">
      <h1 className="text-3xl font-semibold">Privacy Policy — Osteq</h1>
      <p className="mt-2 text-sm text-neutral-500">Effective date: August 5, 2026</p>

      <p className="mt-8">
        Osteq (&ldquo;we&rdquo;, &ldquo;us&rdquo;, &ldquo;our&rdquo;) operates the Osteq mobile app and website, a
        trade platform for AV (audio-visual) professionals. This policy explains what information we collect, why,
        and how you can control it.
      </p>
      <p className="mt-4">By creating an account or otherwise using Osteq, you agree to this policy.</p>

      <h2 className="mt-10 text-xl font-semibold">1. Who this applies to</h2>
      <p className="mt-3">
        Osteq is a business-to-business (B2B) platform for AV trade professionals — resellers, integrators, and
        installers. It is not directed at, or intended for use by, children. We do not knowingly collect information
        from anyone under 18.
      </p>

      <h2 className="mt-10 text-xl font-semibold">2. Information we collect</h2>
      <p className="mt-3">We only collect what&rsquo;s needed to run your trade account and fulfill orders:</p>

      <p className="mt-4 font-medium">Account information</p>
      <ul className="mt-2 list-disc pl-6">
        <li>
          Email address and password (password is stored as a one-way hash — we never see or store it in plain text)
        </li>
      </ul>

      <p className="mt-4 font-medium">Business &amp; trade information</p>
      <ul className="mt-2 list-disc pl-6">
        <li>Business name and business type, submitted when you apply for a trade account</li>
        <li>Phone number</li>
      </ul>

      <p className="mt-4 font-medium">Shipping &amp; billing information</p>
      <ul className="mt-2 list-disc pl-6">
        <li>
          Delivery addresses you save (street address, city, state, postal code, country, and a phone number for
          delivery)
        </li>
      </ul>

      <p className="mt-4 font-medium">Order activity</p>
      <ul className="mt-2 list-disc pl-6">
        <li>Products you browse, quotes you request, orders you place, and your order/quote history</li>
      </ul>

      <p className="mt-4">
        Osteq does not currently collect payment card details or process payments in-app. If that changes, we&rsquo;ll
        update this policy to explain how payment information is handled.
      </p>

      <h2 className="mt-10 text-xl font-semibold">3. How we use your information</h2>
      <ul className="mt-3 list-disc pl-6">
        <li>To create and manage your trade account</li>
        <li>
          To review and approve (or decline) trade account applications — a member of our staff manually reviews
          each application
        </li>
        <li>To process quotes, orders, and deliveries</li>
        <li>To communicate with you about your account, quotes, and orders</li>
        <li>To maintain the security and integrity of the platform</li>
      </ul>
      <p className="mt-4">
        We do not use your information for advertising, and we do not sell your information to anyone.
      </p>

      <h2 className="mt-10 text-xl font-semibold">4. Who we share information with</h2>
      <p className="mt-3">
        We do not share your information with third parties for marketing purposes. We share information only with:
      </p>
      <ul className="mt-2 list-disc pl-6">
        <li>
          Service providers that help us run the platform (e.g. our hosting/infrastructure provider), bound to only
          use your data to provide that service
        </li>
        <li>Law enforcement or regulators, if required by law</li>
      </ul>
      <p className="mt-4">We do not use third-party analytics or advertising SDKs in the app.</p>

      <h2 className="mt-10 text-xl font-semibold">5. Data storage &amp; security</h2>
      <p className="mt-3">
        Your data is stored on servers we control, with access restricted to authorized staff. Connections between
        the app and our servers are encrypted (HTTPS/TLS). Passwords are stored using industry-standard one-way
        hashing, not in plain text.
      </p>
      <p className="mt-4">
        No system is perfectly secure, and we can&rsquo;t guarantee absolute security, but we take reasonable steps
        to protect your information.
      </p>

      <h2 className="mt-10 text-xl font-semibold">6. Data retention</h2>
      <p className="mt-3">
        We retain your account and order information for as long as your account is active, and for a reasonable
        period afterward to comply with legal, accounting, or reporting obligations. You can request deletion at any
        time (see below).
      </p>

      <h2 className="mt-10 text-xl font-semibold">7. Your rights</h2>
      <p className="mt-3">You can:</p>
      <ul className="mt-2 list-disc pl-6">
        <li>
          <span className="font-medium">Access</span> the personal information we hold about you
        </li>
        <li>
          <span className="font-medium">Correct</span> inaccurate information (most of this you can edit directly in
          the app, under Account)
        </li>
        <li>
          <span className="font-medium">Delete</span> your account and associated personal information, subject to
          any legal retention requirements (e.g. records of completed transactions)
        </li>
      </ul>
      <p className="mt-4">
        To exercise any of these rights, contact us at{" "}
        <a href="mailto:privacy@osteq.in" className="underline">
          privacy@osteq.in
        </a>
        .
      </p>

      <h2 className="mt-10 text-xl font-semibold">8. Changes to this policy</h2>
      <p className="mt-3">
        We may update this policy from time to time. If we make material changes, we&rsquo;ll notify you in the app
        or by email before they take effect. The &ldquo;Effective date&rdquo; above reflects the latest revision.
      </p>

      <h2 className="mt-10 text-xl font-semibold">9. Contact us</h2>
      <p className="mt-3">Questions about this policy or your data:</p>
      <p className="mt-3">
        <span className="font-medium">Qube Technologies</span>
        <br />
        APPA Junction, Snehita Hills, Himayat Sagar Village, Hyderabad, Telangana 500091, India
        <br />
        Email:{" "}
        <a href="mailto:privacy@osteq.in" className="underline">
          privacy@osteq.in
        </a>
      </p>
    </main>
  );
}
