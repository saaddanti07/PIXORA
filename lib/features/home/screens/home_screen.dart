import 'package:flutter/material.dart';
import 'package:pixora/app/localization/l10n.dart';
import 'package:pixora/app/theme/app_spacing.dart';
import 'package:pixora/core/widgets/section_header.dart';
import 'package:pixora/features/history/data/history_repository.dart';
import 'package:pixora/features/image_engine/models/processing_policy.dart';
import 'package:pixora/features/image_engine/services/image_engine_registry.dart';
import 'package:pixora/features/home/data/creative_tools.dart';
import 'package:pixora/features/home/widgets/coming_soon_sheet.dart';
import 'package:pixora/features/home/widgets/home_header.dart';
import 'package:pixora/features/home/widgets/recent_activity_card.dart';
import 'package:pixora/features/home/widgets/restoration_hero_card.dart';
import 'package:pixora/features/home/widgets/tool_grid.dart';
import 'package:pixora/features/image_picker/models/image_selection_messages.dart';
import 'package:pixora/features/image_picker/models/picked_image.dart';
import 'package:pixora/features/image_picker/screens/image_preview_screen.dart';
import 'package:pixora/features/image_picker/services/device_image_picker_service.dart';
import 'package:pixora/features/image_picker/services/image_selection_controller.dart';

/// The PIXORA dashboard: restore a photo, discover the creative tools, and see
/// recent activity.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.historyRepository,
    required this.onOpenSettings,
    required this.onOpenHistory,
    this.selectionController,
    this.engineRegistry,
    this.processingPolicy,
    super.key,
  });

  final HistoryRepository historyRepository;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenHistory;

  /// Injected in tests; production builds create the device-backed controller.
  final ImageSelectionController? selectionController;

  /// The processors this build can run; forwarded to the preview screen.
  final ImageEngineRegistry? engineRegistry;

  /// Device-derived processing limits; forwarded to the preview screen.
  final ProcessingPolicy? processingPolicy;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ImageSelectionController _selectionController =
      widget.selectionController ??
          ImageSelectionController(picker: DeviceImagePickerService());

  bool _isPicking = false;

  Future<void> _choosePhoto() async {
    if (_isPicking) {
      return;
    }
    setState(() => _isPicking = true);

    PickedImage? picked;
    try {
      picked = await _selectionController.pickImage();
    } on ImageSelectionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(imageSelectionErrorMessage(context.l10n, error.kind)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }

    if (!mounted) {
      return;
    }
    if (picked == null) {
      return;
    }

    final PickedImage image = picked;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ImagePreviewScreen(
          image: image,
          onPickAnother: _selectionController.pickImage,
          engineRegistry: widget.engineRegistry,
          historyRepository: widget.historyRepository,
          processingPolicy: widget.processingPolicy,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final List<CreativeTool> tools = buildCreativeTools(l10n);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.md,
          AppSpacing.screen,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          HomeHeader(onOpenSettings: widget.onOpenSettings),
          const SizedBox(height: AppSpacing.xl),
          Text(l10n.homeWelcomeTitle, style: textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(l10n.homeWelcomeSubtitle, style: textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.lg),
          RestorationHeroCard(
            onChoosePhoto: _choosePhoto,
            isPicking: _isPicking,
          ),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(
            title: l10n.homeCreativeToolsTitle,
            subtitle: l10n.homeCreativeToolsSubtitle,
          ),
          const SizedBox(height: AppSpacing.md),
          ToolGrid(
            tools: tools,
            onToolSelected: (CreativeTool tool) =>
                ComingSoonSheet.show(context, tool),
          ),
          const SizedBox(height: AppSpacing.sm),
          SectionHeader(
            title: l10n.homeRecentTitle,
            trailing: TextButton(
              onPressed: widget.onOpenHistory,
              child: Text(l10n.homeRecentAction),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ListenableBuilder(
            listenable: widget.historyRepository,
            builder: (BuildContext context, Widget? child) => RecentActivityCard(
              entries: widget.historyRepository.load(),
              onViewAll: widget.onOpenHistory,
            ),
          ),
        ],
      ),
    );
  }
}
