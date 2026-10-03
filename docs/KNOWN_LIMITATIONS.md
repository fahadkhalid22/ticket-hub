# Known Limitations

1. **Payments are simulated by design.** No real card, JazzCash, Easypaisa or wallet credentials are collected. Replace `SimulatedPaymentProvider` with a certified gateway integration for production.
2. **Push notifications are not configured.** The required in-app notification center and local-ready dependency exist; production push requires FCM/APNs credentials and server delivery configuration.
3. **Simple seat-map editor.** The included owner flow creates rectangular General-category maps. The schema supports coordinates and categories, but a drag-and-drop venue designer would be a future enhancement.
4. **Platform runner boilerplate is generated locally.** `scripts/bootstrap.ps1`/`.sh` runs the installed Flutter SDK's official `flutter create` so Android/iOS/web project files match the evaluator's Flutter version. Application source is not overwritten.
5. **No live device/Supabase execution occurred in the packaging environment** because Flutter, Dart, and a user-owned Supabase project are not available there. Static repository checks were run; the exact commands for real runtime verification are in README and `docs/TEST_REPORT.md`.
6. **Search uses relational filters, not geospatial radius search or fuzzy ranking.** Business/category/location/date/price/event-type/availability filters and the required sorts are implemented through `search_listings`; production search could later add PostGIS radius filters and full-text ranking.
7. **Staff management UI is minimal.** The `staff` authorization table and scanner authorization logic are implemented; a polished invite/remove staff workflow can be added without changing the scanner security model.
