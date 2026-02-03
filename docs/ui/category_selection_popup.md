# Category Selection Popup (Reference)

This document captures the current “Select Category” popup design used in `lib/pages/home.dart` for the task form.

## Where it lives
- File: `lib/pages/home.dart`
- Widget: Category selection dialog shown from the task form

## Visual structure
- Modal dialog with rounded corners and subtle border
- Header row with title and close button
- Search field with icon and accent-focused border
- “Create new” input + Add button
- Scrollable list of categories with active state

## Theme tokens used
- Surface: `AppTheme.surface`, `AppTheme.surfaceLight`
- Border: `AppTheme.surfaceBorder`
- Accent: `AppTheme.accent`
- Text: `AppTheme.textPrimary`, `AppTheme.textSecondary`, `AppTheme.textTertiary`
- Radius: `AppTheme.borderRadiusLg`, `AppTheme.borderRadiusSm`
- Typography: `AppTheme.headlineSmall`, `AppTheme.bodyMedium`, `AppTheme.bodySmall`, `AppTheme.titleSmall`, `AppTheme.labelLarge`, `AppTheme.labelMedium`

## Reference snippet
```dart
Dialog(
  backgroundColor: AppTheme.surface,
  insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
  shape: RoundedRectangleBorder(
    borderRadius: AppTheme.borderRadiusLg,
    side: BorderSide(color: AppTheme.surfaceBorder),
  ),
  child: Container(
    padding: const EdgeInsets.all(16),
    child: SizedBox(
      width: 360,
      height: 440,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text("Select Category", style: AppTheme.headlineSmall),
              ),
              Material(
                color: AppTheme.surfaceLight,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                  splashRadius: 18,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: "Search categories...",
              hintStyle:
                  AppTheme.bodySmall.copyWith(color: AppTheme.textTertiary),
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
                color: AppTheme.textTertiary,
              ),
              filled: true,
              fillColor: AppTheme.surfaceLight,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.surfaceBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.accent),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Create new",
            style: AppTheme.labelMedium.copyWith(color: AppTheme.textTertiary),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: newCategoryController,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: "Add new category",
                    hintStyle: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: AppTheme.surfaceLight,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppTheme.surfaceBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.accent),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: AppTheme.accent,
                borderRadius: AppTheme.borderRadiusSm,
                child: InkWell(
                  borderRadius: AppTheme.borderRadiusSm,
                  onTap: () async {},
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.add, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          "Add",
                          style: AppTheme.labelLarge
                              .copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  ),
)
```

## Notes
- The list items use `AppTheme.surfaceLight` with a subtle accent highlight for the selected category.
- The dialog size is tuned for a balanced, focused selection experience.
