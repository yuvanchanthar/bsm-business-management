import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../core/app_colors.dart';
import '../../../../../models/delivery.dart';
import '../../domain/entities/invoice_template.dart';

// Helper properties for all templates
mixin InvoicePreviewHelper {
  double getDeliveryTotal(Delivery delivery) {
    final items = delivery.products.isNotEmpty ? delivery.products : delivery.items;
    return delivery.deliveryTotal > 0
        ? delivery.deliveryTotal
        : items.fold(0.0, (s, i) => s + i.totalAmount);
  }

  double getFinalPayable(Delivery delivery) {
    return delivery.updatedBalance != 0
        ? delivery.updatedBalance
        : getDeliveryTotal(delivery);
  }
}

// ── Classic Template Widget ──────────────────────────────────────────────
class ClassicInvoicePreview extends StatelessWidget with InvoicePreviewHelper {
  final InvoiceTemplate template;
  final Delivery delivery;

  const ClassicInvoicePreview({super.key, required this.template, required this.delivery});

  @override
  Widget build(BuildContext context) {
    final items = delivery.products.isNotEmpty ? delivery.products : delivery.items;
    final total = getDeliveryTotal(delivery);
    final finalPayable = getFinalPayable(delivery);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(width: 50, height: 50, color: template.primaryColor.withValues(alpha: 0.1), child: Icon(Icons.agriculture, color: template.primaryColor)),
          const SizedBox(height: 12),
          Text('BSM Agro Industry', style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: template.primaryColor)),
          Text('DELIVERY RECEIPT', style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700], letterSpacing: 1.5)),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BILL TO', style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                    Text(delivery.customerName, style: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.bold)),
                    if (delivery.customerPhone?.isNotEmpty == true) Text(delivery.customerPhone!, style: GoogleFonts.roboto(fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('RECEIPT DETAILS', style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                  Text('ID: ${delivery.id}', style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.bold, color: template.primaryColor)),
                  Text(delivery.formattedDate, style: GoogleFonts.roboto(fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(border: Border.all(color: template.primaryColor, width: 2), borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: [
                Container(
                  color: template.accentColor,
                  padding: const EdgeInsets.all(8),
                  child: Row(children: [
                    Expanded(flex: 3, child: Text('Product', style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.bold, color: template.primaryColor))),
                    Expanded(flex: 2, child: Text('Qty', textAlign: TextAlign.center, style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.bold, color: template.primaryColor))),
                    Expanded(flex: 2, child: Text('Amount', textAlign: TextAlign.right, style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.bold, color: template.primaryColor))),
                  ]),
                ),
                ...items.map((item) => Container(
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.black12))),
                  padding: const EdgeInsets.all(8),
                  child: Row(children: [
                    Expanded(flex: 3, child: Text(item.product, style: GoogleFonts.roboto(fontSize: 12))),
                    Expanded(flex: 2, child: Text('${item.qty}', textAlign: TextAlign.center, style: GoogleFonts.roboto(fontSize: 12))),
                    Expanded(flex: 2, child: Text('₹${item.total.toStringAsFixed(0)}', textAlign: TextAlign.right, style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.bold))),
                  ]),
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Delivery Total: ₹${total.toStringAsFixed(0)}', style: GoogleFonts.roboto(fontSize: 12)),
                  if (delivery.previousBalance != 0) Text('Old Balance: ₹${delivery.previousBalance.abs().toStringAsFixed(0)}', style: GoogleFonts.roboto(fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('FINAL PAYABLE: ₹${finalPayable.toStringAsFixed(0)}', style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold, color: template.primaryColor)),
                ],
              )
            ],
          ),
        ],
      ),
    );
  }
}

// ── Modern Template Widget ──────────────────────────────────────────────
class ModernInvoicePreview extends StatelessWidget with InvoicePreviewHelper {
  final InvoiceTemplate template;
  final Delivery delivery;

  const ModernInvoicePreview({super.key, required this.template, required this.delivery});

  @override
  Widget build(BuildContext context) {
    final items = delivery.products.isNotEmpty ? delivery.products : delivery.items;
    final total = getDeliveryTotal(delivery);
    final finalPayable = getFinalPayable(delivery);

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          Container(
            color: template.primaryColor,
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BSM Agro Industry', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('Delivery Invoice', style: GoogleFonts.nunito(fontSize: 12, color: Colors.white70)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('INVOICE', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
                    Text('# ${delivery.id}', style: GoogleFonts.nunito(fontSize: 10, color: Colors.white70)),
                  ],
                )
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BILL TO', style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.bold, color: template.primaryColor)),
                          Text(delivery.customerName, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.bold)),
                          if (delivery.customerPhone?.isNotEmpty == true) Text(delivery.customerPhone!, style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey[700])),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: template.accentColor, borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Priority: ${delivery.priority}', style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.bold)),
                          Text('Status: ${delivery.status.toUpperCase()}', style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Column(
                  children: [
                    Container(
                      color: template.primaryColor,
                      padding: const EdgeInsets.all(8),
                      child: Row(children: [
                        Expanded(flex: 3, child: Text('ITEM', style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))),
                        Expanded(flex: 2, child: Text('QTY', textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))),
                        Expanded(flex: 2, child: Text('TOTAL', textAlign: TextAlign.right, style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white))),
                      ]),
                    ),
                    ...items.asMap().entries.map((e) => Container(
                      color: e.key.isOdd ? template.accentColor : Colors.white,
                      padding: const EdgeInsets.all(8),
                      child: Row(children: [
                        Expanded(flex: 3, child: Text(e.value.product, style: GoogleFonts.nunito(fontSize: 12))),
                        Expanded(flex: 2, child: Text('${e.value.qty}', textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 12))),
                        Expanded(flex: 2, child: Text('₹${e.value.total.toStringAsFixed(0)}', textAlign: TextAlign.right, style: GoogleFonts.nunito(fontSize: 12))),
                      ]),
                    )),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Subtotal: ₹${total.toStringAsFixed(0)}', style: GoogleFonts.nunito(fontSize: 12)),
                        if (delivery.previousBalance != 0) Text('Old Balance: ₹${delivery.previousBalance.abs().toStringAsFixed(0)}', style: GoogleFonts.nunito(fontSize: 12)),
                        const SizedBox(height: 8),
                        Container(
                          color: template.primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text('AMOUNT DUE: ₹${finalPayable.toStringAsFixed(0)}', style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ],
                    )
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ── Dark Template Widget ────────────────────────────────────────────────
class DarkInvoicePreview extends StatelessWidget with InvoicePreviewHelper {
  final InvoiceTemplate template;
  final Delivery delivery;

  const DarkInvoicePreview({super.key, required this.template, required this.delivery});

  @override
  Widget build(BuildContext context) {
    final items = delivery.products.isNotEmpty ? delivery.products : delivery.items;
    final total = getDeliveryTotal(delivery);
    final finalPayable = getFinalPayable(delivery);

    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1E1E2C), borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('BSM AGRO', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('INVOICE', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w300, color: template.primaryColor)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invoice to:', style: GoogleFonts.poppins(fontSize: 10, color: Colors.white54)),
                  Text(delivery.customerName, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  if (delivery.customerPhone?.isNotEmpty == true) Text(delivery.customerPhone!, style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Invoice No:', style: GoogleFonts.poppins(fontSize: 10, color: Colors.white54)),
                  Text('#${delivery.id}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white)),
                ],
              )
            ],
          ),
          const SizedBox(height: 24),
          Column(
            children: [
              Row(children: [
                Expanded(flex: 3, child: Text('DESCRIPTION', style: GoogleFonts.poppins(fontSize: 10, color: template.primaryColor))),
                Expanded(flex: 2, child: Text('QTY', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 10, color: template.primaryColor))),
                Expanded(flex: 2, child: Text('TOTAL', textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 10, color: template.primaryColor))),
              ]),
              const Divider(color: Colors.white24, thickness: 1),
              ...items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Expanded(flex: 3, child: Text(item.product, style: GoogleFonts.poppins(fontSize: 12, color: Colors.white))),
                  Expanded(flex: 2, child: Text('${item.qty}', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70))),
                  Expanded(flex: 2, child: Text('₹${item.total.toStringAsFixed(0)}', textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 12, color: Colors.white))),
                ]),
              )),
              const Divider(color: Colors.white24, thickness: 1),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Thank you!', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white54)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Subtotal: ₹${total.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
                  if (delivery.previousBalance != 0) Text('Balance: ₹${delivery.previousBalance.abs().toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text('TOTAL: ₹${finalPayable.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: template.primaryColor)),
                ],
              )
            ],
          )
        ],
      ),
    );
  }
}

// ── GST Template Widget ──────────────────────────────────────────────────
class GstInvoicePreview extends StatelessWidget with InvoicePreviewHelper {
  final InvoiceTemplate template;
  final Delivery delivery;

  const GstInvoicePreview({super.key, required this.template, required this.delivery});

  @override
  Widget build(BuildContext context) {
    final items = delivery.products.isNotEmpty ? delivery.products : delivery.items;
    final total = getDeliveryTotal(delivery);
    final finalPayable = getFinalPayable(delivery);
    final cgst = total * 0.09;
    final sgst = total * 0.09;

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: template.primaryColor, width: 2)),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Text('TAX INVOICE', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: template.primaryColor, letterSpacing: 2)),
                Text('BSM Agro Industry', style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold)),
                Text('GSTIN: 33AAAAA0000A1Z5', style: GoogleFonts.lato(fontSize: 10, color: Colors.grey[700])),
              ],
            ),
          ),
          const Divider(thickness: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Billed To:', style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.bold)),
                  Text(delivery.customerName, style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('GSTIN: ${delivery.invoice?.gstNumber ?? 'URD'}', style: GoogleFonts.lato(fontSize: 10)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Invoice No: ${delivery.id}', style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.bold)),
                  Text('Date: ${delivery.formattedDate}', style: GoogleFonts.lato(fontSize: 10)),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          Table(
            border: TableBorder.all(color: Colors.grey[300]!),
            columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(1), 2: FlexColumnWidth(2)},
            children: [
              TableRow(
                decoration: BoxDecoration(color: template.accentColor),
                children: [
                  Padding(padding: const EdgeInsets.all(6), child: Text('Item Description', style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.bold))),
                  Padding(padding: const EdgeInsets.all(6), child: Text('Qty', textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.bold))),
                  Padding(padding: const EdgeInsets.all(6), child: Text('Amount', textAlign: TextAlign.right, style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.bold))),
                ],
              ),
              ...items.map((item) => TableRow(
                children: [
                  Padding(padding: const EdgeInsets.all(6), child: Text(item.product, style: GoogleFonts.lato(fontSize: 10))),
                  Padding(padding: const EdgeInsets.all(6), child: Text('${item.qty}', textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 10))),
                  Padding(padding: const EdgeInsets.all(6), child: Text('₹${item.total.toStringAsFixed(0)}', textAlign: TextAlign.right, style: GoogleFonts.lato(fontSize: 10))),
                ],
              )),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Taxable Value: ₹${total.toStringAsFixed(0)}', style: GoogleFonts.lato(fontSize: 10)),
                  Text('CGST @9%: ₹${cgst.toStringAsFixed(0)}', style: GoogleFonts.lato(fontSize: 10)),
                  Text('SGST @9%: ₹${sgst.toStringAsFixed(0)}', style: GoogleFonts.lato(fontSize: 10)),
                  const SizedBox(height: 4),
                  Text('Grand Total: ₹${finalPayable.toStringAsFixed(0)}', style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: template.primaryColor)),
                ],
              )
            ],
          )
        ],
      ),
    );
  }
}

// ── Corporate Template Widget ────────────────────────────────────────────
class CorporateInvoicePreview extends StatelessWidget with InvoicePreviewHelper {
  final InvoiceTemplate template;
  final Delivery delivery;

  const CorporateInvoicePreview({super.key, required this.template, required this.delivery});

  @override
  Widget build(BuildContext context) {
    final items = delivery.products.isNotEmpty ? delivery.products : delivery.items;
    final total = getDeliveryTotal(delivery);
    final finalPayable = getFinalPayable(delivery);

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(0), border: Border.all(color: Colors.grey[300]!)),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('BSM AGRO', style: GoogleFonts.openSans(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                  Text('Corporate Invoice', style: GoogleFonts.openSans(fontSize: 12, color: template.primaryColor, fontWeight: FontWeight.w600)),
                ],
              ),
              Container(padding: const EdgeInsets.all(8), color: template.primaryColor, child: Text('INVOICE', style: GoogleFonts.openSans(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('INVOICE TO:', style: GoogleFonts.openSans(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey[500])),
                  Text(delivery.customerName, style: GoogleFonts.openSans(fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('INVOICE NO: ${delivery.id}', style: GoogleFonts.openSans(fontSize: 10, fontWeight: FontWeight.bold)),
                  Text('DATE: ${delivery.formattedDate}', style: GoogleFonts.openSans(fontSize: 10, color: Colors.grey[600])),
                ],
              )
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.only(bottom: 8),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black, width: 1.5))),
            child: Row(children: [
              Expanded(flex: 3, child: Text('DESCRIPTION', style: GoogleFonts.openSans(fontSize: 10, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('QTY', textAlign: TextAlign.center, style: GoogleFonts.openSans(fontSize: 10, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('TOTAL', textAlign: TextAlign.right, style: GoogleFonts.openSans(fontSize: 10, fontWeight: FontWeight.bold))),
            ]),
          ),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Expanded(flex: 3, child: Text(item.product, style: GoogleFonts.openSans(fontSize: 11))),
              Expanded(flex: 2, child: Text('${item.qty}', textAlign: TextAlign.center, style: GoogleFonts.openSans(fontSize: 11))),
              Expanded(flex: 2, child: Text('₹${item.total.toStringAsFixed(0)}', textAlign: TextAlign.right, style: GoogleFonts.openSans(fontSize: 11))),
            ]),
          )),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('SUBTOTAL: ₹${total.toStringAsFixed(0)}', style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                  if (delivery.previousBalance != 0) Text('BALANCE: ₹${delivery.previousBalance.abs().toStringAsFixed(0)}', style: GoogleFonts.openSans(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                  const SizedBox(height: 8),
                  Text('TOTAL DUE: ₹${finalPayable.toStringAsFixed(0)}', style: GoogleFonts.openSans(fontSize: 14, fontWeight: FontWeight.bold, color: template.primaryColor)),
                ],
              )
            ],
          )
        ],
      ),
    );
  }
}

// ── Widget Selector ────────────────────────────────────────────────────────
Widget getTemplateWidget(String templateId, InvoiceTemplate template, Delivery delivery) {
  final normalizedId = templateId.trim().toLowerCase();
  debugPrint('[TemplateWidget] Rendering preview for ID: "$templateId" (Normalized: "$normalizedId")');
  
  switch (normalizedId) {
    case 'classic':
      return ClassicInvoicePreview(key: ValueKey(normalizedId), template: template, delivery: delivery);
    case 'modern':
      return ModernInvoicePreview(key: ValueKey(normalizedId), template: template, delivery: delivery);
    case 'dark':
      return DarkInvoicePreview(key: ValueKey(normalizedId), template: template, delivery: delivery);
    case 'gst':
      return GstInvoicePreview(key: ValueKey(normalizedId), template: template, delivery: delivery);
    case 'corporate':
      return CorporateInvoicePreview(key: ValueKey(normalizedId), template: template, delivery: delivery);
    default:
      debugPrint('[TemplateWidget] WARNING: Unknown template ID "$templateId", falling back to Classic');
      return ClassicInvoicePreview(key: ValueKey(normalizedId), template: template, delivery: delivery);
  }
}
