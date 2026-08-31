with open('lib/purchase_service.dart', 'r', encoding='utf-8') as f:
    c = f.read()

old = """      } else if (purchase.status == PurchaseStatus.error) {
        final msg = purchase.error?.message ?? 'Purchase failed';
        print('Purchase error: ' + msg);
        onPurchaseError?.call(msg);
      }"""

new = """      } else if (purchase.status == PurchaseStatus.error) {
        final err = purchase.error;
        final msg = 'Purchase failed: code=' + (err?.code ?? 'unknown') + 
                    ' message=' + (err?.message ?? 'no message') +
                    ' details=' + (err?.details?.toString() ?? 'none');
        print(msg);
        onPurchaseError?.call(err?.message ?? 'Purchase failed');
      }"""

c = c.replace(old, new)

with open('lib/purchase_service.dart', 'w', encoding='utf-8') as f:
    f.write(c)
print('Fixed.')
