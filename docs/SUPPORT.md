# Optional one-time support

The Mac invitation is designed to appear once per macOS user profile, after at
least five minutes of streaming, when the user clicks Stop in the visible, active
Mac settings window. It never interrupts initial pairing or active
streaming. Closing, Escape, declining or opening checkout all consume the single
automatic invitation. Reset Settings and normal app updates do not reset it.
Users can voluntarily reopen it with Support this free app when configured.

All features stay free. The app opens an external checkout only after a click,
does not process card details, and never treats opening checkout as payment success.
The prompt is only in the Mac app to avoid asking again on the Huawei receiver.

## Payment destination required before activation

No YouWo-owned support payment link has been verified yet. The feature remains
inactive until a reviewed `resources/SupportOffer.json` is supplied:

```json
{
  "checkoutURL": "REPLACE_WITH_VERIFIED_YOUWO_HTTPS_CHECKOUT",
  "paymentType": "one_time"
}
```

Verify the merchant recipient, amount/currency or custom-amount behavior, and
that checkout has no recurring interval before packaging it. The schema is not
payment-provider verification. Do not use the inherited SideScreen funding links;
those belong to its original developer. Do not put private API credentials or
private checkout-session links in the public configuration. An amount is not
advertised in the app until it has been chosen in the payment provider.
