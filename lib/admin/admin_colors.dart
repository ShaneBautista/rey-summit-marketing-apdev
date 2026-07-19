import 'package:flutter/material.dart';

// Admin portal now shares the same green identity as the customer app,
// so both feel like one product. Status colors (green/amber/red for
// stock levels) stay distinct from the primary so they still read
// clearly against it.
const Color kAdminBlue = Color(0xFF1F4B41); // primary accent, header pill — same as customer kDarkGreen
const Color kAdminDarkBlue = Color(0xFF17342C); // headings — slightly deeper green
const Color kAdminBg = Color(0xFFE9F4EF); // page background — same as customer kLightMint
const Color kAdminCardGrey = Color(0xFF8B9A94); // secondary text — same as customer kFieldGrey
const Color kAdminBorder = Color(0xFFE3E8E6);
const Color kAdminShadow = Color.fromRGBO(31, 75, 65, 0.08);
const Color kAdminGreen = Color(0xFF2FAE6A); // in-stock / positive — brighter green, reads against primary
const Color kAdminAmber = Color(0xFFE3A511); // low stock
const Color kAdminRed = Color(0xFFE0453F); // out of stock / negative
