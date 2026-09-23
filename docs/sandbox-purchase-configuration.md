# Sandbox purchase configuration

- Bundle ID: `com.huankecontact.test`
- Sandbox product ID supplied by the owner: `1coins_19`
- Product availability and association with this app have not yet been verified with Apple.
- H5 price requests must include `1coins_19` in `productIds`; purchase requests must use `goodsCode: "1coins_19"`. The native bridge forwards the supplied ID to StoreKit and server order creation without substituting a different product.
- The backend must configure this bundle and the corresponding product mapping.
- Sandbox credentials are entered on the test device only and must not be added to source code, logs or configuration files.
- Changing the bundle ID creates a separate app installation and a separate local data namespace; existing app data is not automatically migrated.
