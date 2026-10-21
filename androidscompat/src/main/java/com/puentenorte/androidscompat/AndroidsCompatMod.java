package com.puentenorte.androidscompat;

import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.commands.CommandSourceStack;
import net.minecraft.commands.Commands;
import com.mojang.brigadier.arguments.StringArgumentType;
import net.minecraft.network.chat.Component;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.SimpleContainer;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EquipmentSlot;
import net.minecraft.world.entity.HumanoidArm;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.entity.PathfinderMob;
import net.minecraft.world.entity.ai.goal.Goal;
import net.minecraft.world.entity.ai.goal.WrappedGoal;
import net.minecraft.world.entity.ai.attributes.AttributeInstance;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.effect.MobEffects;
import net.minecraft.world.entity.monster.Enemy;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ArmorItem;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.phys.Vec3;
import net.minecraftforge.event.RegisterCommandsEvent;
import net.minecraftforge.event.ServerChatEvent;
import net.minecraftforge.event.entity.living.LivingDamageEvent;
import net.minecraftforge.event.entity.living.LivingDeathEvent;
import net.minecraftforge.event.entity.living.LivingEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.ModList;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.joml.Vector3f;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * Server-side bridge for CC:Androids, NTGL and Immersive Aircraft.
 *
 * NTGL already installs GunAttackGoal on PathfinderMobs holding an IWeapon.
 * The missing piece for CC:Androids is a vanilla Mob target. This class adds
 * that target without calling the Android Lua attack() method, so it cannot
 * turn a ranged weapon into a melee attack. When an Android is mounted in an
 * Immersive Aircraft vehicle, the same bridge supplies flight inputs and calls
 * the vehicle's mounted weapons directly on the server.
 */
@Mod(AndroidsCompatMod.MOD_ID)
public final class AndroidsCompatMod {
    public static final String MOD_ID = "androidscompat";
    private static final Logger LOGGER = LoggerFactory.getLogger(MOD_ID);

    private static final String ANDROID_BASE_CLASS =
            "com.thunderbear06.entity.android.BaseAndroidEntity";
    private static final String NTGL_WEAPON_CLASS =
            "com.nukateam.ntgl.common.foundation.item.interfaces.IWeapon";
    private static final String NTGL_GOAL_CLASS =
            "com.nukateam.ntgl.common.foundation.goals.GunAttackGoal";
    private static final String NTGL_WEAPON_DATA_CLASS =
            "com.nukateam.ntgl.common.data.WeaponData";
    private static final String NTGL_STATE_HELPER_CLASS =
            "com.nukateam.ntgl.common.util.util.WeaponStateHelper";
    private static final String NTGL_AMMO_HOLDER_CLASS =
            "com.nukateam.ntgl.common.data.holders.AmmoHolder";
    private static final String NTGL_INVENTORY_UTIL_CLASS =
            "com.nukateam.ntgl.common.util.util.InventoryUtil";
    private static final String NTGL_AMMO_CONTEXT_CLASS =
            "com.nukateam.ntgl.common.util.helpers.context.IAmmoContext";
    private static final String RELOAD_CHAT = "!androidscompat reload";
    private static final String AUTOPILOT_CHAT_PREFIX = "!androidscompat autopilot";
    private static final String ORDER_CHAT_PREFIX = "!androidscompat order";
    private static final String CAPTURE_CHAT = "!androidscompat capture";
    private static final String IMPRISON_CHAT = "!androidscompat imprison";
    private static final String RELEASE_CHAT = "!androidscompat release";
    private static final String SPY_CHAT_PREFIX = "!androidscompat spy";
    private static final String INTEL_CHAT_PREFIX = "!androidscompat intel";
    private static final String AIRCRAFT_VEHICLE_CLASS =
            "immersive_aircraft.entity.VehicleEntity";
    private static final String AIRCRAFT_INVENTORY_CLASS =
            "immersive_aircraft.entity.InventoryVehicleEntity";
    private static final double TARGET_RANGE = 32.0D;
    private static final int CHECK_EVERY_TICKS = 5;
    private static final int DIRECT_GROUND_FIRE_COOLDOWN = 10;
    private static final long XP_PER_LEVEL_SQUARE = 100L;
    private static final String XP_TAG = "androidscompat_xp";
    private static final String LEVEL_TAG = "androidscompat_level";
    private static final String BASE_SPEED_TAG = "androidscompat_base_speed";
    private static final String BASE_HEALTH_TAG = "androidscompat_base_health";
    private static final String BASE_FOLLOW_TAG = "androidscompat_base_follow";
    private static final String SQUAD_TAG = "androidscompat_squad";
    private static final String ORDER_TAG = "androidscompat_order";
    private static final String ORDER_TARGET_TAG = "androidscompat_order_target";
    private static final String OWNER_TAG = "androidscompat_owner";
    private static final String AIR_ROLE_TAG = "androidscompat_air_role";
    private static final String SPY_TAG = "androidscompat_spy";
    private static final String SPY_COVER_TAG = "androidscompat_spy_cover";
    private static final String SPY_COVER_SET_TAG = "androidscompat_spy_cover_set";
    private static final String CAPTURED_BY_TAG = "androidscompat_captured_by";
    private static final String IMPRISONED_TAG = "androidscompat_imprisoned";
    private static final String PRISON_X_TAG = "androidscompat_prison_x";
    private static final String PRISON_Y_TAG = "androidscompat_prison_y";
    private static final String PRISON_Z_TAG = "androidscompat_prison_z";
    private static final String[] OPTIONAL_MODS = {
            "ntgl", "cgs", "immersive_aircraft", "man_of_many_planes",
            "curios", "sophisticatedbackpacks", "create", "createbigcannons",
            "create_radar", "createaddition", "mekanism", "mekanismgenerators",
            "advancedperipherals", "computercraft", "cccbridge", "carryon",
            "securitycraft", "easy_npc", "alexsmobs", "vampirism", "werewolves",
            "shieldexp", "puffish_skills", "appliedenergistics2", "steamsails"
    };
    private static final double AIRCRAFT_TARGET_RANGE = 64.0D;
    private static final int AIRCRAFT_FIRE_COOLDOWN = 15;

    private enum AircraftRole {
        COMBAT,
        BOMBER,
        TRANSPORT
    }

    private enum AircraftOrder {
        PATROL,
        FOLLOW,
        RETURN,
        HOLD
    }

    private static final class AircraftNavigation {
        private final Vec3 home;
        private final long started;
        private AircraftOrder order = AircraftOrder.PATROL;
        private UUID followTarget;

        private AircraftNavigation(Vec3 home, long started) {
            this.home = home;
            this.started = started;
        }
    }

    private static volatile Class<?> ntglWeaponType;
    private static volatile boolean checkedNtgl;
    private static volatile Class<?> aircraftVehicleType;
    private static volatile Class<?> aircraftInventoryType;
    private static volatile boolean checkedAircraft;
    private static final Map<UUID, Long> aircraftNextFire = new HashMap<>();
    private static final Map<UUID, Long> groundNextFire = new HashMap<>();
    private static final Map<UUID, AircraftRole> aircraftRoles = new HashMap<>();
    private static final Map<UUID, AircraftNavigation> aircraftNavigation = new HashMap<>();
    private static final Map<UUID, Boolean> aircraftControlLogged = new HashMap<>();
    private static final Map<UUID, Integer> lastLoggedLevel = new HashMap<>();

    public AndroidsCompatMod() {
        net.minecraftforge.common.MinecraftForge.EVENT_BUS.register(this);
        LOGGER.info("CC:Androids compatibility loaded; NTGL weapons use server-side targeting");
    }

    @SubscribeEvent
    public void onRegisterCommands(RegisterCommandsEvent event) {
        event.getDispatcher().register(Commands.literal("androidscompat")
                .requires(source -> source.hasPermission(2))
                .then(Commands.literal("mount")
                        .executes(context -> mountNearest(context.getSource())))
                .then(Commands.literal("dismount")
                        .executes(context -> dismountNearest(context.getSource())))
                .then(Commands.literal("reload")
                        .executes(context -> reloadNearest(context.getSource())))
                .then(Commands.literal("stats")
                        .executes(context -> statsNearest(context.getSource())))
                .then(Commands.literal("compat")
                        .executes(context -> compatibilityStatus(context.getSource())))
                .then(Commands.literal("squad")
                        .then(Commands.argument("name", StringArgumentType.word())
                                .executes(context -> assignSquad(
                                        context.getSource(), StringArgumentType.getString(
                                                context, "name")))))
                .then(Commands.literal("order")
                        .then(Commands.argument("order", StringArgumentType.word())
                                .executes(context -> orderNearest(
                                        context.getSource(), StringArgumentType.getString(
                                                context, "order"), ""))
                                .then(Commands.argument("target", StringArgumentType.word())
                                        .executes(context -> orderNearest(
                                                context.getSource(), StringArgumentType.getString(
                                                        context, "order"),
                                                StringArgumentType.getString(
                                                        context, "target"))))))
                .then(Commands.literal("capture")
                        .executes(context -> captureNearest(context.getSource(), false)))
                .then(Commands.literal("imprison")
                        .executes(context -> captureNearest(context.getSource(), true)))
                .then(Commands.literal("release")
                        .executes(context -> releaseNearest(context.getSource())))
                .then(Commands.literal("spy")
                        .then(Commands.literal("on")
                                .executes(context -> setNearestSpy(
                                        context.getSource(), true, "")))
                        .then(Commands.literal("off")
                                .executes(context -> setNearestSpy(
                                        context.getSource(), false, "")))
                        .then(Commands.literal("cover")
                                .then(Commands.argument("name", StringArgumentType.word())
                                        .executes(context -> setNearestSpy(
                                                context.getSource(), true,
                                                StringArgumentType.getString(
                                                        context, "name"))))))
                .then(Commands.literal("intel")
                        .executes(context -> intelNearest(context.getSource())))
                .then(Commands.literal("mode")
                        .then(Commands.literal("combat")
                                .executes(context -> setNearestAircraftRole(
                                        context.getSource(), AircraftRole.COMBAT)))
                        .then(Commands.literal("bomber")
                                .executes(context -> setNearestAircraftRole(
                                        context.getSource(), AircraftRole.BOMBER)))
                        .then(Commands.literal("transport")
                                .executes(context -> setNearestAircraftRole(
                                        context.getSource(), AircraftRole.TRANSPORT)))));
    }

    /** Receives the R-key marker sent by the Android computer. */
    @SubscribeEvent
    public void onServerChat(ServerChatEvent event) {
        String text = event.getRawText().trim();
        if (handleAutopilotChat(event, text)) {
            return;
        }
        if (handleOrderChat(event, text)) {
            return;
        }
        if (handleCaptureChat(event, text)) {
            return;
        }
        if (handleSpyChat(event, text)) {
            return;
        }
        if (!RELOAD_CHAT.equalsIgnoreCase(text)) {
            return;
        }

        event.setCanceled(true);
        ServerPlayer player = event.getPlayer();
        ServerLevel level = (ServerLevel) player.level();
        Mob android = level.getEntitiesOfClass(
                        Mob.class, player.getBoundingBox().inflate(8.0D),
                        candidate -> isAndroid(candidate))
                .stream()
                .min(Comparator.comparingDouble(
                        (Mob candidate) -> player.distanceToSqr(candidate)))
                .orElse(null);
        if (android != null) {
            reloadAndroid(android);
        }
    }

    /** Called by the independent aircraft Lua roles. */
    private boolean handleAutopilotChat(ServerChatEvent event, String text) {
        String lower = text.toLowerCase(java.util.Locale.ROOT);
        if (!lower.startsWith(AUTOPILOT_CHAT_PREFIX)) {
            return false;
        }

        event.setCanceled(true);
        String[] autopilotParts = text.substring(AUTOPILOT_CHAT_PREFIX.length()).trim()
                .split("\\s+");
        String roleName = autopilotParts.length == 0 ? "" : autopilotParts[0]
                .toLowerCase(java.util.Locale.ROOT);
        AircraftRole role;
        try {
            role = AircraftRole.valueOf(roleName.toUpperCase(java.util.Locale.ROOT));
        } catch (IllegalArgumentException error) {
            event.getPlayer().sendSystemMessage(Component.literal(
                    "Rol aereo desconocido: " + roleName));
            return true;
        }

        ServerPlayer player = event.getPlayer();
        ServerLevel level = (ServerLevel) player.level();
        Mob android = autopilotParts.length > 1
                ? androidByUuid(level, autopilotParts[1]) : null;
        if (android == null) {
            android = nearestAndroid(player, 16.0D);
        }
        if (android == null) {
            player.sendSystemMessage(Component.literal(
                    "Autopiloto: no encuentro un Android libre cerca."));
            return true;
        }
        final Mob controlledAndroid = android;

        if (android.isPassenger() && isAircraft(android.getVehicle())) {
            rememberOwner(android, player);
            aircraftRoles.put(android.getUUID(), role);
            android.getPersistentData().putString(AIR_ROLE_TAG,
                    role.name().toLowerCase(java.util.Locale.ROOT));
            aircraftNavigation.computeIfAbsent(android.getUUID(), key ->
                    new AircraftNavigation(controlledAndroid.getVehicle().position(),
                            level.getGameTime()));
            return true;
        }
        if (android.isPassenger()) {
            player.sendSystemMessage(Component.literal(
                    "Autopiloto: el Android cercano ya esta montado en otro vehiculo."));
            return true;
        }

        Entity aircraft = level.getEntitiesOfClass(
                        Entity.class, android.getBoundingBox().inflate(12.0D),
                        candidate -> isAircraft(candidate)
                                && candidate.getPassengers().isEmpty())
                .stream()
                .min(Comparator.comparingDouble(
                        (Entity candidate) -> controlledAndroid.distanceToSqr(candidate)))
                .orElse(null);
        if (aircraft == null || !android.startRiding(aircraft, true)) {
            player.sendSystemMessage(Component.literal(
                    "Autopiloto: acerca un avion vacio al Android."));
            return true;
        }

        aircraftRoles.put(android.getUUID(), role);
        android.getPersistentData().putString(AIR_ROLE_TAG,
                role.name().toLowerCase(java.util.Locale.ROOT));
        rememberOwner(android, player);
        aircraftNavigation.put(android.getUUID(),
                new AircraftNavigation(aircraft.position(), level.getGameTime()));
        player.sendSystemMessage(Component.literal(
                "Autopiloto " + roleName + ": Android montado y rol activado."));
        LOGGER.info("Aircraft autopilot requested by Lua: Android {} -> {} ({})",
                android.getUUID(), roleName, aircraft.getClass().getName());
        return true;
    }

    /** Receives patrol/follow/return/hold orders from an aircraft Lua role. */
    private boolean handleOrderChat(ServerChatEvent event, String text) {
        String lower = text.toLowerCase(java.util.Locale.ROOT);
        if (!lower.startsWith(ORDER_CHAT_PREFIX)) {
            return false;
        }

        event.setCanceled(true);
        String[] parts = text.substring(ORDER_CHAT_PREFIX.length()).trim()
                .split("\\s+");
        if (parts.length == 0 || parts[0].isEmpty()) {
            return true;
        }

        ServerPlayer player = event.getPlayer();
        ServerLevel level = (ServerLevel) player.level();
        int commandIndex = 0;
        Mob android = null;
        if (parts.length > 1) {
            android = androidByUuid(level, parts[0]);
            if (android != null) {
                commandIndex = 1;
            }
        }
        if (android == null) {
            android = nearestAndroid(player, 32.0D);
        }
        if (android == null) {
            player.sendSystemMessage(Component.literal(
                    "No hay un Android cerca para recibir la orden."));
            return true;
        }
        final Mob controlledAndroid = android;

        if (commandIndex >= parts.length) {
            return true;
        }
        String command = parts[commandIndex].toLowerCase(java.util.Locale.ROOT);
        String targetName = commandIndex + 1 < parts.length
                ? parts[commandIndex + 1] : "";
        if ("capture".equals(command)) {
            captureNearby(android, false);
            return true;
        }
        if ("imprison".equals(command)) {
            captureNearby(android, true);
            return true;
        }
        if (!isKnownOrder(command)) {
            player.sendSystemMessage(Component.literal(
                    "Orden desconocida. Usa hold, guard, patrol, follow, rescue o logistics."));
            return true;
        }

        if (!android.isPassenger() || !isAircraft(android.getVehicle())) {
            android.getPersistentData().putString(ORDER_TAG, command);
            if (!targetName.isEmpty()) {
                android.getPersistentData().putString(ORDER_TARGET_TAG, targetName);
            } else {
                android.getPersistentData().remove(ORDER_TARGET_TAG);
            }
            rememberOwner(android, player);
            player.sendSystemMessage(Component.literal(
                    "Orden terrestre aplicada: " + command));
            return true;
        }

        AircraftOrder order;
        try {
            order = AircraftOrder.valueOf(command.toUpperCase(java.util.Locale.ROOT));
        } catch (IllegalArgumentException error) {
            // Ground-only orders are valid for Androids but not aircraft.
            player.sendSystemMessage(Component.literal(
                    "Orden no compatible con avion: " + command));
            return true;
        }

        AircraftNavigation navigation = aircraftNavigation.computeIfAbsent(
                android.getUUID(), key -> new AircraftNavigation(
                        controlledAndroid.getVehicle().position(),
                        controlledAndroid.level().getGameTime()));
        navigation.order = order;
        if (order == AircraftOrder.FOLLOW && !targetName.isEmpty()) {
            Player followTarget = android.level().getServer().getPlayerList()
                    .getPlayerByName(targetName);
            navigation.followTarget = followTarget == null
                    ? player.getUUID() : followTarget.getUUID();
        } else if (order != AircraftOrder.FOLLOW) {
            navigation.followTarget = null;
        }
        player.sendSystemMessage(Component.literal(
                "Orden aerea aplicada: " + order.name().toLowerCase(java.util.Locale.ROOT)));
        return true;
    }

    /** Handles capture/release requests sent by an independent Lua role. */
    private boolean handleCaptureChat(ServerChatEvent event, String text) {
        boolean captureRequest = chatCommandMatches(text, CAPTURE_CHAT);
        boolean imprisonRequest = chatCommandMatches(text, IMPRISON_CHAT);
        boolean releaseRequest = chatCommandMatches(text, RELEASE_CHAT);
        if (!captureRequest && !imprisonRequest && !releaseRequest) {
            return false;
        }
        event.setCanceled(true);
        ServerPlayer player = event.getPlayer();
        ServerLevel level = (ServerLevel) player.level();
        String capturePrefix = CAPTURE_CHAT;
        String imprisonPrefix = IMPRISON_CHAT;
        String releasePrefix = RELEASE_CHAT;
        String requestedId = text.length() > capturePrefix.length()
                && text.regionMatches(true, 0, capturePrefix, 0, capturePrefix.length())
                ? text.substring(capturePrefix.length()).trim()
                : text.length() > imprisonPrefix.length()
                && text.regionMatches(true, 0, imprisonPrefix, 0, imprisonPrefix.length())
                ? text.substring(imprisonPrefix.length()).trim()
                : text.length() > releasePrefix.length()
                && text.regionMatches(true, 0, releasePrefix, 0, releasePrefix.length())
                ? text.substring(releasePrefix.length()).trim() : "";
        Mob android = requestedId.isEmpty() ? null : androidByUuid(level, requestedId);
        if (android == null) {
            android = nearestAndroid(player, 20.0D);
        }
        if (captureRequest || imprisonRequest) {
            boolean imprison = imprisonRequest;
            if (android != null && isOwnedBy(android, player)) {
                captureNearby(android, imprison);
            } else {
                LivingEntity target = findCapturable(player, 12.0D);
                if (target == null) {
                    player.sendSystemMessage(Component.literal(
                            "No hay un enemigo o Android enemigo capturable cerca."));
                } else {
                    captureEntity(player, target, imprison);
                    player.sendSystemMessage(Component.literal(
                            (imprison ? "Encarcelado: " : "Capturado: ")
                                    + target.getName().getString()));
                }
            }
        } else {
            if (android != null && isOwnedBy(android, player)) {
                releaseNearby(android);
            } else {
                if (!releaseCapturedByPlayer(player)) {
                    player.sendSystemMessage(Component.literal("No hay retenidos tuyos cerca."));
                }
            }
        }
        return true;
    }

    private static boolean chatCommandMatches(String text, String command) {
        return text.equalsIgnoreCase(command)
                || (text.length() > command.length()
                && text.regionMatches(true, 0, command, 0, command.length())
                && Character.isWhitespace(text.charAt(command.length())));
    }

    private boolean handleSpyChat(ServerChatEvent event, String text) {
        String lower = text.toLowerCase(java.util.Locale.ROOT);
        boolean spyRequest = lower.startsWith(SPY_CHAT_PREFIX)
                && (lower.length() == SPY_CHAT_PREFIX.length()
                || Character.isWhitespace(lower.charAt(SPY_CHAT_PREFIX.length())));
        boolean intelRequest = lower.startsWith(INTEL_CHAT_PREFIX)
                && (lower.length() == INTEL_CHAT_PREFIX.length()
                || Character.isWhitespace(lower.charAt(INTEL_CHAT_PREFIX.length())));
        if (!spyRequest && !intelRequest) {
            return false;
        }

        event.setCanceled(true);
        ServerPlayer player = event.getPlayer();
        ServerLevel level = (ServerLevel) player.level();
        String prefix = spyRequest ? SPY_CHAT_PREFIX : INTEL_CHAT_PREFIX;
        String[] parts = text.substring(prefix.length()).trim().split("\\s+");
        String action = intelRequest ? "intel"
                : (parts.length == 0 ? "" : parts[0].toLowerCase(java.util.Locale.ROOT));
        String requestedId = intelRequest
                ? (parts.length > 0 && isUuidText(parts[0]) ? parts[0] : "")
                : (parts.length > 1 ? parts[1] : "");
        Mob android = requestedId.isEmpty() ? null : androidByUuid(level, requestedId);
        if (android == null) {
            android = nearestAndroid(player, 20.0D);
        }
        if (android == null) {
            player.sendSystemMessage(Component.literal("No hay un Android de espionaje cerca."));
            return true;
        }

        if (intelRequest || "intel".equals(action) || "report".equals(action)) {
            if (!isOwnedBy(android, player)
                    && android.getPersistentData().hasUUID(OWNER_TAG)) {
                player.sendSystemMessage(Component.literal("Ese informe no es accesible."));
            } else {
                collectIntel(player, android);
            }
            return true;
        }
        if (!isOwnedBy(android, player)
                && android.getPersistentData().hasUUID(OWNER_TAG)) {
            player.sendSystemMessage(Component.literal("Ese Android no acepta tu orden."));
            return true;
        }
        if ("off".equals(action) || "stop".equals(action)) {
            disableSpy(android);
            player.sendSystemMessage(Component.literal("Modo espia desactivado."));
        } else {
            String cover = parts.length > 1 && !isUuidText(parts[1]) ? parts[1] : "";
            enableSpy(android, player, cover);
            player.sendSystemMessage(Component.literal(
                    "Modo espia activo" + (cover.isEmpty() ? "" : " | cobertura=" + cover)));
        }
        return true;
    }

    private static boolean isUuidText(String value) {
        try {
            UUID.fromString(value);
            return true;
        } catch (IllegalArgumentException error) {
            return false;
        }
    }

    private static int setNearestSpy(CommandSourceStack source, boolean enabled,
                                     String cover) {
        Entity caller = source.getEntity();
        if (!(caller instanceof Player player)) {
            source.sendFailure(Component.literal("Solo un jugador puede configurar un espia."));
            return 0;
        }
        Mob android = nearestAndroid(player, 24.0D);
        if (android == null) {
            source.sendFailure(Component.literal("No hay un Android cerca."));
            return 0;
        }
        if (android.getPersistentData().hasUUID(OWNER_TAG)
                && !isOwnedBy(android, player)) {
            source.sendFailure(Component.literal("Ese Android pertenece a otro jugador."));
            return 0;
        }
        if (enabled) {
            enableSpy(android, player, cover);
        } else {
            disableSpy(android);
        }
        source.sendSuccess(() -> Component.literal(
                enabled ? "Modo espia activo." : "Modo espia desactivado."), true);
        return 1;
    }

    private static int intelNearest(CommandSourceStack source) {
        Entity caller = source.getEntity();
        if (!(caller instanceof Player player)) {
            source.sendFailure(Component.literal("Solo un jugador puede pedir inteligencia."));
            return 0;
        }
        Mob android = nearestAndroid(player, 32.0D);
        if (android == null) {
            source.sendFailure(Component.literal("No hay un Android cerca."));
            return 0;
        }
        collectIntel(player, android);
        return 1;
    }

    private static void enableSpy(Mob android, Player owner, String cover) {
        rememberOwner(android, owner);
        android.getPersistentData().putBoolean(SPY_TAG, true);
        if (!cover.isEmpty()) {
            android.getPersistentData().putString(SPY_COVER_TAG, cover);
            if (android.getCustomName() == null) {
                android.setCustomName(Component.literal(cover));
                android.getPersistentData().putBoolean(SPY_COVER_SET_TAG, true);
            }
        }
        android.setTarget(null);
        android.getNavigation().stop();
    }

    private static void disableSpy(Mob android) {
        android.getPersistentData().remove(SPY_TAG);
        android.getPersistentData().remove(SPY_COVER_TAG);
        if (android.getPersistentData().getBoolean(SPY_COVER_SET_TAG)) {
            android.setCustomName(null);
        }
        android.getPersistentData().remove(SPY_COVER_SET_TAG);
        android.setTarget(null);
        android.getNavigation().stop();
    }

    private static boolean isSpy(Mob android) {
        return android.getPersistentData().getBoolean(SPY_TAG);
    }

    private static void concealSpy(Mob spy) {
        if (!(spy.level() instanceof ServerLevel level)) {
            return;
        }
        level.getEntitiesOfClass(Mob.class, spy.getBoundingBox().inflate(24.0D),
                candidate -> candidate instanceof Enemy && candidate.getTarget() == spy)
                .forEach(candidate -> candidate.setTarget(null));
    }

    private static void collectIntel(Player player, Mob spy) {
        ServerLevel level = (ServerLevel) player.level();
        double range = 64.0D;
        List<LivingEntity> living = level.getEntitiesOfClass(
                LivingEntity.class, spy.getBoundingBox().inflate(range),
                target -> target != spy && target.isAlive());
        long players = living.stream().filter(entity -> entity instanceof Player).count();
        long enemies = living.stream().filter(entity -> entity instanceof Enemy).count();
        long androids = living.stream().filter(AndroidsCompatMod::isAndroid).count();
        long aircraft = level.getEntitiesOfClass(
                Entity.class, spy.getBoundingBox().inflate(range),
                entity -> entity != spy && isAircraft(entity)).size();
        String cover = spy.getPersistentData().getString(SPY_COVER_TAG);
        player.sendSystemMessage(Component.literal(
                "INTEL | espia=" + spy.getName().getString()
                        + " | cobertura=" + (cover.isEmpty() ? "ninguna" : cover)
                        + " | jugadores=" + players
                        + " | enemigos=" + enemies
                        + " | androids=" + androids
                        + " | aviones=" + aircraft));
        living.stream()
                .filter(entity -> entity instanceof Player || entity instanceof Enemy)
                .sorted(Comparator.comparingDouble(spy::distanceToSqr))
                .limit(8)
                .forEach(entity -> player.sendSystemMessage(Component.literal(
                        "  contacto " + entity.getName().getString()
                                + " | distancia=" + String.format(java.util.Locale.ROOT,
                                "%.1f", Math.sqrt(spy.distanceToSqr(entity))))));
    }

    private static boolean isKnownOrder(String command) {
        return "hold".equals(command) || "patrol".equals(command)
                || "guard".equals(command) || "follow".equals(command)
                || "rescue".equals(command) || "logistics".equals(command)
                || "return".equals(command);
    }

    private static void rememberOwner(Mob android, Player owner) {
        if (!android.getPersistentData().hasUUID(OWNER_TAG)) {
            android.getPersistentData().putUUID(OWNER_TAG, owner.getUUID());
        }
    }

    private static boolean isOwnedBy(Mob android, Player player) {
        return android.getPersistentData().hasUUID(OWNER_TAG)
                && player.getUUID().equals(android.getPersistentData().getUUID(OWNER_TAG));
    }

    private static int assignSquad(CommandSourceStack source, String name) {
        Entity caller = source.getEntity();
        if (!(caller instanceof Player player)) {
            source.sendFailure(Component.literal("Solo un jugador puede asignar escuadras."));
            return 0;
        }
        Mob android = nearestAndroid(player, 24.0D);
        if (android == null) {
            source.sendFailure(Component.literal("No hay un Android cercano."));
            return 0;
        }
        String squad = name.trim().toLowerCase(java.util.Locale.ROOT);
        android.getPersistentData().putString(SQUAD_TAG, squad);
        rememberOwner(android, player);
        source.sendSuccess(() -> Component.literal(
                "Escuadra " + squad + " asignada a " + android.getName().getString()), true);
        return 1;
    }

    private static int orderNearest(CommandSourceStack source,
                                    String requested, String target) {
        Entity caller = source.getEntity();
        if (!(caller instanceof Player player)) {
            source.sendFailure(Component.literal("Solo un jugador puede dar ordenes."));
            return 0;
        }
        String command = requested.toLowerCase(java.util.Locale.ROOT);
        if ("all".equals(command)) {
            command = target.toLowerCase(java.util.Locale.ROOT);
            target = "";
            if (!isKnownOrder(command)) {
                source.sendFailure(Component.literal("Orden desconocida."));
                return 0;
            }
            int count = 0;
            for (Mob android : nearbyAndroids(player, 48.0D)) {
                applyGroundOrAircraftOrder(android, command, target, player);
                count++;
            }
            final String appliedOrder = command;
            final int appliedCount = count;
            source.sendSuccess(() -> Component.literal(
                    "Orden " + appliedOrder + " aplicada a " + appliedCount + " Androids."), true);
            return count;
        }
        if (!isKnownOrder(command)) {
            source.sendFailure(Component.literal(
                    "Orden desconocida. Usa hold, guard, patrol, follow, rescue o logistics."));
            return 0;
        }
        Mob android = nearestAndroid(player, 32.0D);
        if (android == null) {
            source.sendFailure(Component.literal("No hay un Android cercano."));
            return 0;
        }
        applyGroundOrAircraftOrder(android, command, target, player);
        final String appliedOrder = command;
        source.sendSuccess(() -> Component.literal(
                "Orden " + appliedOrder + " aplicada a " + android.getName().getString()), true);
        return 1;
    }

    private static List<Mob> nearbyAndroids(Player player, double range) {
        return ((ServerLevel) player.level()).getEntitiesOfClass(
                Mob.class, player.getBoundingBox().inflate(range),
                AndroidsCompatMod::isAndroid);
    }

    private static void applyGroundOrAircraftOrder(Mob android, String command,
                                                   String target, Player issuer) {
        if (android.isPassenger() && isAircraft(android.getVehicle())) {
            try {
                AircraftOrder aircraftOrder = AircraftOrder.valueOf(
                        command.toUpperCase(java.util.Locale.ROOT));
                AircraftNavigation navigation = aircraftNavigation.computeIfAbsent(
                        android.getUUID(), key -> new AircraftNavigation(
                                android.getVehicle().position(), android.level().getGameTime()));
                navigation.order = aircraftOrder;
                if (aircraftOrder == AircraftOrder.FOLLOW && !target.isEmpty()) {
                    Player follow = android.level().getServer().getPlayerList()
                            .getPlayerByName(target);
                    navigation.followTarget = follow == null ? issuer.getUUID() : follow.getUUID();
                } else if (aircraftOrder != AircraftOrder.FOLLOW) {
                    navigation.followTarget = null;
                }
                rememberOwner(android, issuer);
                return;
            } catch (IllegalArgumentException ignored) {
                // guard/rescue/logistics are ground coordination orders.
            }
        }

        android.getPersistentData().putString(ORDER_TAG, command);
        if (!target.isEmpty()) {
            android.getPersistentData().putString(ORDER_TARGET_TAG, target);
        } else {
            android.getPersistentData().remove(ORDER_TARGET_TAG);
        }
        rememberOwner(android, issuer);
    }

    private static void applyGroundOrder(Mob android) {
        String order = android.getPersistentData().getString(ORDER_TAG)
                .toLowerCase(java.util.Locale.ROOT);
        if (order.isEmpty() || (android.isPassenger() && isAircraft(android.getVehicle()))) {
            return;
        }
        if ("hold".equals(order)) {
            android.setTarget(null);
            android.getNavigation().stop();
            return;
        }
        ServerLevel level = (ServerLevel) android.level();
        if ("follow".equals(order)) {
            String targetName = android.getPersistentData().getString(ORDER_TARGET_TAG);
            Player target = targetName.isEmpty() ? null
                    : level.getServer().getPlayerList().getPlayerByName(targetName);
            if (target != null) {
                android.getNavigation().moveTo(target, 1.05D);
                android.setTarget(null);
            }
        } else if ("rescue".equals(order)) {
            LivingEntity prisoner = level.getEntitiesOfClass(
                            LivingEntity.class, android.getBoundingBox().inflate(48.0D),
                            candidate -> candidate != android
                                    && candidate.getPersistentData().hasUUID(CAPTURED_BY_TAG))
                    .stream().min(Comparator.comparingDouble(android::distanceToSqr)).orElse(null);
            if (prisoner != null) {
                android.getNavigation().moveTo(prisoner, 1.1D);
                android.setTarget(null);
            }
        } else if ("logistics".equals(order)) {
            Mob transport = level.getEntitiesOfClass(
                            Mob.class, android.getBoundingBox().inflate(96.0D),
                            candidate -> isAndroid(candidate)
                                    && "transport".equals(candidate.getPersistentData()
                                            .getString("androidscompat_air_role")))
                    .stream().min(Comparator.comparingDouble(android::distanceToSqr)).orElse(null);
            if (transport != null) {
                android.getNavigation().moveTo(transport, 1.0D);
                android.setTarget(null);
            }
        }
    }

    private static int captureNearest(CommandSourceStack source, boolean imprison) {
        Entity caller = source.getEntity();
        if (!(caller instanceof Player player)) {
            source.sendFailure(Component.literal("Solo un jugador puede capturar."));
            return 0;
        }
        LivingEntity target = findCapturable(player, 12.0D);
        if (target == null) {
            source.sendFailure(Component.literal(
                    "No hay un enemigo, Android o jugador capturable cerca."));
            return 0;
        }
        captureEntity(player, target, imprison);
        source.sendSuccess(() -> Component.literal(
                (imprison ? "Encarcelado: " : "Capturado: ")
                        + target.getName().getString()), true);
        return 1;
    }

    private static int releaseNearest(CommandSourceStack source) {
        Entity caller = source.getEntity();
        if (!(caller instanceof Player player)) {
            source.sendFailure(Component.literal("Solo un jugador puede liberar."));
            return 0;
        }
        LivingEntity target = findCapturedByPlayer(player);
        if (target == null) {
            source.sendFailure(Component.literal("No hay retenidos tuyos cerca."));
            return 0;
        }
        releaseEntity(target);
        source.sendSuccess(() -> Component.literal(
                "Liberado: " + target.getName().getString()), true);
        return 1;
    }

    private static boolean releaseCapturedByPlayer(Player player) {
        LivingEntity target = findCapturedByPlayer(player);
        if (target == null) {
            return false;
        }
        releaseEntity(target);
        player.sendSystemMessage(Component.literal(
                "Liberado: " + target.getName().getString()));
        return true;
    }

    private static LivingEntity findCapturedByPlayer(Player player) {
        ServerLevel level = (ServerLevel) player.level();
        return level.getEntitiesOfClass(
                        LivingEntity.class, player.getBoundingBox().inflate(32.0D),
                        candidate -> isCapturedByPlayerOrOwnedAndroid(candidate, player))
                .stream()
                .min(Comparator.comparingDouble(player::distanceToSqr))
                .orElse(null);
    }

    private static void captureNearby(LivingEntity captor, boolean imprison) {
        LivingEntity target = findCapturable(captor, 10.0D);
        if (target == null) {
            LOGGER.debug("No capturable target near {}", captor.getUUID());
            return;
        }
        captureEntity(captor, target, imprison);
        LOGGER.info("{} captured {}{}", captor.getUUID(), target.getUUID(),
                imprison ? " and imprisoned" : "");
    }

    private static void releaseNearby(LivingEntity captor) {
        if (!(captor.level() instanceof ServerLevel level)) {
            return;
        }
        LivingEntity target = level.getEntitiesOfClass(
                        LivingEntity.class, captor.getBoundingBox().inflate(24.0D),
                        candidate -> candidate.getPersistentData().hasUUID(CAPTURED_BY_TAG)
                                && captor.getUUID().equals(candidate.getPersistentData()
                                .getUUID(CAPTURED_BY_TAG)))
                .stream()
                .min(Comparator.comparingDouble(captor::distanceToSqr))
                .orElse(null);
        if (target != null) {
            releaseEntity(target);
            LOGGER.info("{} released {}", captor.getUUID(), target.getUUID());
        }
    }

    private static LivingEntity findCapturable(LivingEntity captor, double range) {
        if (!(captor.level() instanceof ServerLevel level)) {
            return null;
        }
        return level.getEntitiesOfClass(
                        LivingEntity.class, captor.getBoundingBox().inflate(range),
                        candidate -> candidate != captor
                                && candidate.isAlive()
                                && isCapturableType(candidate)
                                && !candidate.getPersistentData().hasUUID(CAPTURED_BY_TAG)
                                && !isFriendlyTo(captor, candidate))
                .stream()
                .min(Comparator.comparingDouble(captor::distanceToSqr))
                .orElse(null);
    }

    private static boolean isCapturableType(LivingEntity target) {
        return target instanceof Player || isAndroid(target) || target instanceof Enemy;
    }

    private static boolean isFriendlyTo(LivingEntity captor, LivingEntity target) {
        if (target instanceof Player player
                && captor.getPersistentData().hasUUID(OWNER_TAG)
                && player.getUUID().equals(captor.getPersistentData().getUUID(OWNER_TAG))) {
            return true;
        }
        if (isAndroid(target) && captor.getPersistentData().hasUUID(OWNER_TAG)
                && target.getPersistentData().hasUUID(OWNER_TAG)
                && captor.getPersistentData().getUUID(OWNER_TAG)
                .equals(target.getPersistentData().getUUID(OWNER_TAG))) {
            return true;
        }
        String captorSquad = captor.getPersistentData().getString(SQUAD_TAG);
        String targetSquad = target.getPersistentData().getString(SQUAD_TAG);
        return !captorSquad.isEmpty() && captorSquad.equals(targetSquad);
    }

    private static boolean isCapturedByPlayerOrOwnedAndroid(LivingEntity target,
                                                              Player player) {
        if (!target.getPersistentData().hasUUID(CAPTURED_BY_TAG)) {
            return false;
        }
        UUID captorId = target.getPersistentData().getUUID(CAPTURED_BY_TAG);
        if (player.getUUID().equals(captorId)) {
            return true;
        }
        if (!(player.level() instanceof ServerLevel level)) {
            return false;
        }
        Entity captor = level.getEntity(captorId);
        return captor instanceof Mob mob
                && mob.getPersistentData().hasUUID(OWNER_TAG)
                && player.getUUID().equals(mob.getPersistentData().getUUID(OWNER_TAG));
    }

    private static void captureEntity(LivingEntity captor, LivingEntity target,
                                      boolean imprison) {
        if (target == captor) {
            return;
        }
        if (target.isPassenger()) {
            target.stopRiding();
        }
        target.getPersistentData().putUUID(CAPTURED_BY_TAG, captor.getUUID());
        target.getPersistentData().putBoolean(IMPRISONED_TAG, imprison);
        if (imprison) {
            target.getPersistentData().putDouble(PRISON_X_TAG, captor.getX());
            target.getPersistentData().putDouble(PRISON_Y_TAG, captor.getY() + 1.0D);
            target.getPersistentData().putDouble(PRISON_Z_TAG, captor.getZ());
        } else {
            target.getPersistentData().remove(PRISON_X_TAG);
            target.getPersistentData().remove(PRISON_Y_TAG);
            target.getPersistentData().remove(PRISON_Z_TAG);
        }
        target.setNoGravity(true);
        target.setDeltaMovement(Vec3.ZERO);
        target.addEffect(new MobEffectInstance(MobEffects.MOVEMENT_SLOWDOWN,
                40, 255, false, false));
        target.addEffect(new MobEffectInstance(MobEffects.JUMP,
                40, 250, false, false));
        if (target instanceof Mob mob) {
            mob.setTarget(null);
            mob.getNavigation().stop();
        }
    }

    private static void enforceDetention(LivingEntity target) {
        if (!target.getPersistentData().hasUUID(CAPTURED_BY_TAG)) {
            return;
        }
        if (!(target.level() instanceof ServerLevel level)) {
            return;
        }
        Entity captor = level.getEntity(target.getPersistentData().getUUID(CAPTURED_BY_TAG));
        if (!(captor instanceof LivingEntity livingCaptor) || !livingCaptor.isAlive()) {
            releaseEntity(target);
            return;
        }
        if (target.isPassenger()) {
            target.stopRiding();
        }
        target.setNoGravity(true);
        if (target.getPersistentData().getBoolean(IMPRISONED_TAG)
                && target.getPersistentData().contains(PRISON_X_TAG)) {
            target.setPos(target.getPersistentData().getDouble(PRISON_X_TAG),
                    target.getPersistentData().getDouble(PRISON_Y_TAG),
                    target.getPersistentData().getDouble(PRISON_Z_TAG));
        } else {
            target.setPos(livingCaptor.getX(), livingCaptor.getY() + 1.0D,
                    livingCaptor.getZ());
        }
        target.setDeltaMovement(Vec3.ZERO);
        if (target.tickCount % 10 == 0) {
            target.addEffect(new MobEffectInstance(MobEffects.MOVEMENT_SLOWDOWN,
                    40, 255, false, false));
            target.addEffect(new MobEffectInstance(MobEffects.JUMP,
                    40, 250, false, false));
        }
        if (target instanceof Mob mob) {
            mob.setTarget(null);
            mob.getNavigation().stop();
        }
    }

    private static void releaseEntity(LivingEntity target) {
        target.getPersistentData().remove(CAPTURED_BY_TAG);
        target.getPersistentData().remove(IMPRISONED_TAG);
        target.getPersistentData().remove(PRISON_X_TAG);
        target.getPersistentData().remove(PRISON_Y_TAG);
        target.getPersistentData().remove(PRISON_Z_TAG);
        target.setNoGravity(false);
        target.removeEffect(MobEffects.MOVEMENT_SLOWDOWN);
        target.removeEffect(MobEffects.JUMP);
    }

    @SubscribeEvent
    public void onLivingTick(LivingEvent.LivingTickEvent event) {
        LivingEntity living = event.getEntity();
        if (!(living.level() instanceof ServerLevel)) {
            return;
        }
        enforceDetention(living);
        if (!(living instanceof Mob mob)) {
            return;
        }
        if (!isAndroid(mob)) {
            return;
        }

        // Aircraft control must run every passenger tick.  Immersive Aircraft
        // clears inputs when the passenger is not a Player, so doing this only
        // every few ticks makes the plane lose control and dive.
        controlAircraft(mob);

        if (mob.tickCount % CHECK_EVERY_TICKS != 0) {
            return;
        }

        updateProgression(mob);
        equipArmorAndBackpack(mob);

        if (isSpy(mob)) {
            concealSpy(mob);
            mob.setTarget(null);
            mob.getNavigation().stop();
            return;
        }

        moveNtglWeaponToMainHand(mob);
        ItemStack weapon = mob.getMainHandItem();
        if (isNtglWeapon(weapon)) {
            LivingEntity current = mob.getTarget();
            if (!isValidTarget(mob, current)) {
                mob.setTarget(findNearestEnemy(mob));
            }
            ensureGunAttackGoal(mob);
            ensureAutomaticReload(mob, weapon);
            directGroundShot(mob, mob.getTarget());
        }

    }

    @SubscribeEvent
    public void onLivingDamage(LivingDamageEvent event) {
        Entity attacker = event.getSource().getEntity();
        if (event.getEntity() instanceof Mob target && isSpy(target)
                && attacker instanceof Enemy) {
            event.setCanceled(true);
            return;
        }
        if (attacker instanceof Mob android && isAndroid(android)
                && event.getEntity() != android) {
            grantExperience(android, Math.max(1L,
                    Math.round(event.getAmount() * 2.0F)));
        }
    }

    @SubscribeEvent
    public void onLivingDeath(LivingDeathEvent event) {
        Entity attacker = event.getSource().getEntity();
        if (attacker instanceof Mob android && isAndroid(android)
                && event.getEntity() != android) {
            grantExperience(android, 50L
                    + Math.max(1L, Math.round(event.getEntity().getMaxHealth())) * 5L);
        }
    }

    /**
     * Drives and arms an Immersive Aircraft when an Android is its first
     * passenger. This is deliberately reflective: the compatibility jar can
     * still load when Immersive Aircraft is not installed.
     */
    private static void controlAircraft(Mob android) {
        Entity vehicle = android.getVehicle();
        if (vehicle == null || !isAircraft(vehicle)
                || !vehicle.getPassengers().contains(android)) {
            // Do not leave an aircraft role attached after dismounting. If
            // this Android is later used as a fusilero or guard, mounting it
            // manually must not resurrect the old autopilot state.
            aircraftRoles.remove(android.getUUID());
            aircraftNavigation.remove(android.getUUID());
            aircraftControlLogged.remove(android.getUUID());
            android.getPersistentData().remove(AIR_ROLE_TAG);
            return;
        }

        // Never infer an aircraft role from the fact that an Android is a
        // passenger.  Fusileros, guards and other ground roles can be mounted
        // accidentally; they must not receive flight controls or aircraft
        // weapons.  A role is assigned only by rol_avion/piloto/bombardero/
        // transportador or by the explicit server command.
        AircraftRole role = aircraftRoles.get(android.getUUID());
        if (role == null) {
            return;
        }

        // Immersive Aircraft is also the superclass of Man of Many Planes
        // aircraft.  Do not require a specific concrete plane class here.
        if (aircraftControlLogged.putIfAbsent(android.getUUID(), Boolean.TRUE) == null) {
            LOGGER.info("Aircraft autopilot active for Android {} in {} (passengers={})",
                    android.getUUID(), vehicle.getClass().getName(),
                    vehicle.getPassengers().size());
        }

        try {
            long tick = vehicle.level().getGameTime();
            AircraftNavigation navigation = aircraftNavigation.computeIfAbsent(
                    android.getUUID(), key -> new AircraftNavigation(
                            vehicle.position(), tick));
            Entity targetAircraft = role == AircraftRole.COMBAT
                    ? findEnemyAircraft(vehicle) : null;
            LivingEntity groundTarget = role == AircraftRole.TRANSPORT
                    ? null
                    : (targetAircraft == null ? findGroundTarget(vehicle) : null);
            Entity followTarget = navigation.order == AircraftOrder.FOLLOW
                    ? findFollowTarget(android, navigation) : null;
            Entity target = followTarget != null ? followTarget
                    : (targetAircraft != null ? targetAircraft : groundTarget);

            boolean takingOff = tick - navigation.started < 100L
                    || (vehicle.onGround() && vehicle.getY() < navigation.home.y + 8.0D);
            Vector3f direction;
            Vector3f weaponDirection = null;
            if (takingOff) {
                direction = takeoffDirection(vehicle);
            } else if (navigation.order == AircraftOrder.RETURN) {
                direction = directionTo(vehicle,
                        new Vec3(navigation.home.x, navigation.home.y + 20.0D,
                                navigation.home.z));
            } else if (navigation.order == AircraftOrder.HOLD) {
                direction = getForwardDirection(vehicle);
            } else if (targetAircraft != null || followTarget != null) {
                // Follow/air-combat may use the real 3D position.  A ground
                // target is handled below at a safe altitude instead of
                // turning the aircraft into a guided projectile.
                direction = directionTo(vehicle, target);
            } else if (groundTarget != null) {
                double safeY = Math.max(groundTarget.getY() + 18.0D,
                        navigation.home.y + 16.0D);
                direction = directionTo(vehicle,
                        new Vec3(groundTarget.getX(), safeY, groundTarget.getZ()));
                weaponDirection = directionTo(vehicle, groundTarget);
            } else {
                direction = patrolDirection(vehicle, navigation, tick);
            }
            if (direction == null) {
                LOGGER.debug("Aircraft autopilot has no direction for {}", android.getUUID());
                return;
            }

            // Inputs are set for versions that honor them. Direct motion below
            // is also applied because IA resets inputs when the passenger is not
            // a Player, which is exactly the CC:Androids case.
            applyFlightInputs(vehicle, direction,
                    navigation.order != AircraftOrder.HOLD);
            applyDirectFlightMotion(vehicle, direction, takingOff,
                    navigation.order == AircraftOrder.HOLD);

            long next = aircraftNextFire.getOrDefault(vehicle.getUUID(), 0L);
            if (target != null && role != AircraftRole.TRANSPORT && tick >= next) {
                fireAircraftWeapons(vehicle,
                        weaponDirection == null ? direction : weaponDirection, role);
                aircraftNextFire.put(vehicle.getUUID(), tick + AIRCRAFT_FIRE_COOLDOWN);
            }
        } catch (RuntimeException error) {
            LOGGER.warn("Aircraft autopilot failed for Android {} in {}",
                    android.getUUID(), vehicle.getClass().getName(), error);
        }
    }

    private static Entity findEnemyAircraft(Entity own) {
        List<Entity> candidates = own.level().getEntitiesOfClass(
                Entity.class,
                own.getBoundingBox().inflate(AIRCRAFT_TARGET_RANGE),
                entity -> entity != own
                        && isAircraft(entity)
                        && !entity.getPassengers().contains(own));

        return candidates.stream()
                .min(Comparator.comparingDouble(own::distanceToSqr))
                .orElse(null);
    }

    private static LivingEntity findGroundTarget(Entity aircraft) {
        List<LivingEntity> candidates = aircraft.level().getEntitiesOfClass(
                LivingEntity.class,
                aircraft.getBoundingBox().inflate(AIRCRAFT_TARGET_RANGE),
                target -> target.isAlive()
                        && target instanceof Enemy
                        && !(target instanceof Player)
                        && target.getVehicle() != aircraft);

        return candidates.stream()
                .min(Comparator.comparingDouble(aircraft::distanceToSqr))
                .orElse(null);
    }

    private static Vector3f directionTo(Entity from, Entity to) {
        Vector3f direction = new Vector3f(
                (float) (to.getX() - from.getX()),
                (float) (to.getY() - from.getY()),
                (float) (to.getZ() - from.getZ()));
        return direction.lengthSquared() < 0.0001F ? null : direction.normalize();
    }

    private static Vector3f directionTo(Entity from, Vec3 to) {
        Vector3f direction = new Vector3f(
                (float) (to.x - from.getX()),
                (float) (to.y - from.getY()),
                (float) (to.z - from.getZ()));
        return direction.lengthSquared() < 0.0001F ? null : direction.normalize();
    }

    private static Vector3f takeoffDirection(Entity aircraft) {
        Vector3f forward = getForwardDirection(aircraft);
        if (forward == null || forward.lengthSquared() < 0.0001F) {
            forward = new Vector3f(0.0F, 0.0F, 1.0F);
        }
        forward.normalize().mul(0.85F);
        forward.y = 0.35F;
        return forward.normalize();
    }

    private static Vector3f patrolDirection(Entity aircraft,
                                             AircraftNavigation navigation,
                                             long tick) {
        double phase = ((tick - navigation.started) % 600L) / 600.0D
                * Math.PI * 2.0D;
        Vec3 point = new Vec3(
                navigation.home.x + Math.cos(phase) * 32.0D,
                navigation.home.y + 20.0D + Math.sin(phase * 2.0D) * 6.0D,
                navigation.home.z + Math.sin(phase) * 32.0D);
        return directionTo(aircraft, point);
    }

    private static Entity findFollowTarget(Mob android, AircraftNavigation navigation) {
        if (navigation.followTarget == null
                || !(android.level() instanceof ServerLevel level)) {
            return null;
        }
        return level.getEntity(navigation.followTarget);
    }

    private static void applyDirectFlightMotion(Entity aircraft, Vector3f direction,
                                                boolean takingOff, boolean holding) {
        Vector3f normalized = new Vector3f(direction);
        if (normalized.lengthSquared() < 0.0001F) {
            return;
        }
        normalized.normalize();
        double speed = holding ? 0.0D : (takingOff ? 0.32D : 0.46D);
        Vec3 desired = new Vec3(
                normalized.x * speed,
                normalized.y * speed,
                normalized.z * speed);
        Vec3 current = aircraft.getDeltaMovement();
        double smoothing = holding ? 0.20D : 0.35D;
        Vec3 velocity = current.scale(1.0D - smoothing).add(desired.scale(smoothing));
        if (!holding && velocity.y < -0.12D) {
            velocity = new Vec3(velocity.x, -0.12D, velocity.z);
        }
        if (!holding && aircraft.getY() < 4.0D && velocity.y < 0.10D) {
            velocity = new Vec3(velocity.x, 0.10D, velocity.z);
        }
        aircraft.setDeltaMovement(velocity);
        aircraft.hasImpulse = true;

        float yaw = (float) Math.toDegrees(Math.atan2(-normalized.x, normalized.z));
        float pitch = (float) Math.toDegrees(Math.asin(-normalized.y));
        aircraft.setYRot(yaw);
        aircraft.setXRot(Math.max(-25.0F, Math.min(25.0F, pitch)));
    }

    private static Vector3f getForwardDirection(Entity aircraft) {
        Object value = invoke(aircraft, "getForwardDirection");
        return value instanceof Vector3f direction ? new Vector3f(direction) : null;
    }

    private static void applyFlightInputs(Entity aircraft, Vector3f targetDirection,
                                          boolean hasTarget) {
        Object rightValue = invoke(aircraft, "getRightDirection");
        Object topValue = invoke(aircraft, "getTopDirection");
        if (!(rightValue instanceof Vector3f right)
                || !(topValue instanceof Vector3f top)) {
            return;
        }

        float turn = clamp(targetDirection.dot(right) * 2.0F);
        float pitch = clamp(targetDirection.dot(top) * 2.0F);
        // IA maps movementY to engine power.  A negative value is the brake /
        // reverse input, so patrol must keep it positive even without a target.
        float throttle = hasTarget ? 1.0F : 0.0F;

        // setEngineTarget exists only in some aircraft versions.  Calling it
        // unconditionally made IA 1.5.0 throw before setInputs was reached.
        invokeIfPresent(aircraft, "setEngineTarget",
                new Class<?>[]{float.class}, throttle);
        invoke(aircraft, "setInputs",
                new Class<?>[]{float.class, float.class, float.class},
                turn, throttle, -pitch);
    }

    private static void invokeIfPresent(Object receiver, String method,
                                        Class<?>[] types, Object... args) {
        try {
            Method target = receiver.getClass().getMethod(method, types);
            target.invoke(receiver, args);
        } catch (NoSuchMethodException ignored) {
            // Optional API: Immersive Aircraft 1.5.0 has no setter, while
            // other aircraft bridges may expose it.
        } catch (IllegalAccessException | InvocationTargetException error) {
            LOGGER.debug("Optional aircraft method {} failed", method, error);
        }
    }

    private static void fireAircraftWeapons(Entity aircraft, Vector3f direction,
                                            AircraftRole role) {
        if (!isAircraftInventory(aircraft)) {
            return;
        }

        Object weaponMap = invoke(aircraft, "getWeapons");
        if (!(weaponMap instanceof Map<?, ?> weapons)) {
            return;
        }

        for (Map.Entry<?, ?> entry : weapons.entrySet()) {
            if (!(entry.getKey() instanceof Number slot)
                    || !(entry.getValue() instanceof List<?> weaponList)) {
                continue;
            }
            for (int index = 0; index < weaponList.size(); index++) {
                if (role == AircraftRole.BOMBER
                        && !isBombBay(weaponList.get(index))) {
                    continue;
                }
                try {
                    invoke(aircraft, "fireWeapon",
                            new Class<?>[]{int.class, int.class, Vector3f.class},
                            slot.intValue(), index, new Vector3f(direction));
                } catch (RuntimeException error) {
                    // Empty magazines and invalid mounts are normal during
                    // gameplay; leave the other mounted weapons operational.
                    LOGGER.debug("Aircraft weapon could not fire", error);
                }
            }
        }
    }

    private static boolean isBombBay(Object weapon) {
        return weapon != null
                && weapon.getClass().getSimpleName().toLowerCase().contains("bombbay");
    }

    private static float clamp(float value) {
        return Math.max(-1.0F, Math.min(1.0F, value));
    }

    private static boolean isAircraft(Entity entity) {
        loadAircraftTypes();
        return aircraftVehicleType != null && aircraftVehicleType.isInstance(entity);
    }

    private static boolean isAircraftInventory(Entity entity) {
        loadAircraftTypes();
        return aircraftInventoryType != null && aircraftInventoryType.isInstance(entity);
    }

    private static void loadAircraftTypes() {
        if (checkedAircraft) {
            return;
        }
        synchronized (AndroidsCompatMod.class) {
            if (checkedAircraft) {
                return;
            }
            try {
                aircraftVehicleType = Class.forName(AIRCRAFT_VEHICLE_CLASS);
                aircraftInventoryType = Class.forName(AIRCRAFT_INVENTORY_CLASS);
                LOGGER.info("Immersive Aircraft detected; Android aircraft combat enabled");
            } catch (ClassNotFoundException ignored) {
                LOGGER.info("Immersive Aircraft not installed; aircraft combat disabled");
            }
            checkedAircraft = true;
        }
    }

    private static Object invoke(Object receiver, String method, Object... args) {
        return invoke(receiver, method, parameterTypes(args), args);
    }

    private static Object invoke(Object receiver, String method, Class<?>[] types,
                                 Object... args) {
        try {
            Method target = receiver.getClass().getMethod(method, types);
            return target.invoke(receiver, args);
        } catch (NoSuchMethodException | IllegalAccessException | InvocationTargetException error) {
            throw new RuntimeException(error);
        }
    }

    private static Class<?>[] parameterTypes(Object[] args) {
        Class<?>[] types = new Class<?>[args.length];
        for (int index = 0; index < args.length; index++) {
            types[index] = args[index].getClass();
        }
        return types;
    }

    private static Mob androidByUuid(ServerLevel level, String value) {
        try {
            Entity entity = level.getEntity(UUID.fromString(value));
            return entity instanceof Mob mob && isAndroid(mob) ? mob : null;
        } catch (IllegalArgumentException error) {
            return null;
        }
    }

    private static Mob nearestAndroid(Player player, double range) {
        ServerLevel level = (ServerLevel) player.level();
        return level.getEntitiesOfClass(
                        Mob.class, player.getBoundingBox().inflate(range),
                        AndroidsCompatMod::isAndroid)
                .stream()
                .min(Comparator.comparingDouble(
                        (Mob candidate) -> player.distanceToSqr(candidate)))
                .orElse(null);
    }

    private static int statsNearest(CommandSourceStack source) {
        Entity caller = source.getEntity();
        if (!(caller instanceof Player player)) {
            source.sendFailure(Component.literal("Solo un jugador puede usar este comando."));
            return 0;
        }
        Mob android = nearestAndroid(player, 32.0D);
        if (android == null) {
            source.sendFailure(Component.literal("No hay un Android cerca."));
            return 0;
        }
        updateProgression(android);
        source.sendSuccess(() -> Component.literal(formatStats(android)), false);
        return 1;
    }

    private static int compatibilityStatus(CommandSourceStack source) {
        List<String> loaded = new java.util.ArrayList<>();
        for (String modId : OPTIONAL_MODS) {
            if (ModList.get().isLoaded(modId)) {
                loaded.add(modId);
            }
        }
        source.sendSuccess(() -> Component.literal(
                "Compat loaded: " + String.join(", ", loaded)), false);
        return 1;
    }

    private static String formatStats(Mob android) {
        long xp = android.getPersistentData().getLong(XP_TAG);
        int level = getLevel(android);
        return "Android nivel=" + level
                + " XP=" + xp
                + " accuracy=" + String.format(java.util.Locale.ROOT, "%.3f", accuracyFor(android))
                + " speed=" + String.format(java.util.Locale.ROOT, "%.3f",
                attributeValue(android, Attributes.MOVEMENT_SPEED));
    }

    private static long experience(Mob android) {
        return Math.max(0L, android.getPersistentData().getLong(XP_TAG));
    }

    private static int getLevel(Mob android) {
        long xp = experience(android);
        double raw = Math.sqrt(xp / (double) XP_PER_LEVEL_SQUARE) + 1.0D;
        return (int) Math.min(Integer.MAX_VALUE, Math.max(1.0D, raw));
    }

    private static void grantExperience(Mob android, long amount) {
        if (amount <= 0L) {
            return;
        }
        long beforeXp = experience(android);
        int beforeLevel = getLevel(android);
        long afterXp = beforeXp > Long.MAX_VALUE - amount
                ? Long.MAX_VALUE : beforeXp + amount;
        android.getPersistentData().putLong(XP_TAG, afterXp);
        updateProgression(android);
        int afterLevel = getLevel(android);
        if (afterLevel > beforeLevel) {
            LOGGER.info("Android {} reached level {} (XP={})",
                    android.getUUID(), afterLevel, afterXp);
            android.level().broadcastEntityEvent(android, (byte) 28);
        }
    }

    private static double attributeValue(Mob android,
                                         net.minecraft.world.entity.ai.attributes.Attribute attribute) {
        AttributeInstance instance = android.getAttribute(attribute);
        return instance == null ? 0.0D : instance.getBaseValue();
    }

    private static void updateProgression(Mob android) {
        var data = android.getPersistentData();
        AttributeInstance speed = android.getAttribute(Attributes.MOVEMENT_SPEED);
        AttributeInstance health = android.getAttribute(Attributes.MAX_HEALTH);
        AttributeInstance follow = android.getAttribute(Attributes.FOLLOW_RANGE);

        if (speed != null && !data.contains(BASE_SPEED_TAG)) {
            data.putDouble(BASE_SPEED_TAG, speed.getBaseValue());
        }
        if (health != null && !data.contains(BASE_HEALTH_TAG)) {
            data.putDouble(BASE_HEALTH_TAG, health.getBaseValue());
        }
        if (follow != null && !data.contains(BASE_FOLLOW_TAG)) {
            data.putDouble(BASE_FOLLOW_TAG, follow.getBaseValue());
        }

        int level = getLevel(android);
        double growth = Math.log1p(level) / Math.log(2.0D);
        if (speed != null && data.contains(BASE_SPEED_TAG)) {
            speed.setBaseValue(data.getDouble(BASE_SPEED_TAG) * (1.0D + growth * 0.03D));
        }
        if (health != null && data.contains(BASE_HEALTH_TAG)) {
            double oldMax = health.getValue();
            health.setBaseValue(data.getDouble(BASE_HEALTH_TAG) + growth * 2.0D);
            if (android.getHealth() > health.getValue()) {
                android.setHealth((float) health.getValue());
            } else if (health.getValue() > oldMax && android.getHealth() > 0.0F) {
                android.heal((float) Math.min(2.0D, health.getValue() - oldMax));
            }
        }
        if (follow != null && data.contains(BASE_FOLLOW_TAG)) {
            follow.setBaseValue(data.getDouble(BASE_FOLLOW_TAG) + growth * 4.0D);
        }

        data.putInt(LEVEL_TAG, level);
        Integer previous = lastLoggedLevel.put(android.getUUID(), level);
        if (previous != null && previous != level) {
            LOGGER.info("Android {} stats improved to level {}", android.getUUID(), level);
        }
    }

    /** Accuracy is skill-based but still has random shot spread. */
    private static float accuracyFor(Mob android) {
        int level = getLevel(android);
        return (float) Math.min(0.98D,
                0.45D + 0.08D * Math.log1p(level));
    }

    private static int mountNearest(CommandSourceStack source) {
        Entity caller = source.getEntity();
        if (!(caller instanceof Player player)) {
            source.sendFailure(Component.literal("Solo un jugador puede usar este comando."));
            return 0;
        }

        ServerLevel level = (ServerLevel) player.level();
        Mob android = level.getEntitiesOfClass(
                        Mob.class, player.getBoundingBox().inflate(8.0D),
                        candidate -> isAndroid(candidate)
                                && !candidate.isPassenger()
                                && aircraftRoles.containsKey(candidate.getUUID()))
                .stream()
                .min(Comparator.comparingDouble((Mob candidate) -> player.distanceToSqr(candidate)))
                .orElse(null);
        Entity aircraft = level.getEntitiesOfClass(
                        Entity.class, player.getBoundingBox().inflate(8.0D),
                        candidate -> isAircraft(candidate) && candidate.getPassengers().isEmpty())
                .stream()
                .min(Comparator.comparingDouble((Entity candidate) -> player.distanceToSqr(candidate)))
                .orElse(null);

        if (android == null || aircraft == null || !android.startRiding(aircraft, true)) {
            source.sendFailure(Component.literal(
                    "Acerca un Android y un avión vacío y vuelve a ejecutar el comando."));
            return 0;
        }
        source.sendSuccess(() -> Component.literal("Android montado: piloto automático activado."), true);
        return 1;
    }

    private static int dismountNearest(CommandSourceStack source) {
        Entity caller = source.getEntity();
        if (!(caller instanceof Player player)) {
            source.sendFailure(Component.literal("Solo un jugador puede usar este comando."));
            return 0;
        }

        ServerLevel level = (ServerLevel) player.level();
        Mob android = level.getEntitiesOfClass(
                        Mob.class, player.getBoundingBox().inflate(8.0D),
                        candidate -> isAndroid(candidate) && candidate.isPassenger())
                .stream()
                .min(Comparator.comparingDouble((Mob candidate) -> player.distanceToSqr(candidate)))
                .orElse(null);
        if (android == null) {
            source.sendFailure(Component.literal("No hay un Android montado cerca."));
            return 0;
        }
        android.stopRiding();
        source.sendSuccess(() -> Component.literal("Android desmontado."), true);
        return 1;
    }

    private static int reloadNearest(CommandSourceStack source) {
        Entity caller = source.getEntity();
        if (!(caller instanceof Player player)) {
            source.sendFailure(Component.literal("Solo un jugador puede usar este comando."));
            return 0;
        }

        ServerLevel level = (ServerLevel) player.level();
        Mob android = level.getEntitiesOfClass(
                        Mob.class, player.getBoundingBox().inflate(8.0D),
                        candidate -> isAndroid(candidate))
                .stream()
                .min(Comparator.comparingDouble(
                        (Mob candidate) -> player.distanceToSqr(candidate)))
                .orElse(null);
        if (android == null || !reloadAndroid(android)) {
            source.sendFailure(Component.literal("No hay un Android con arma NTGL cerca."));
            return 0;
        }
        source.sendSuccess(() -> Component.literal("Recarga solicitada al Android."), true);
        return 1;
    }

    /** Starts NTGL's real server-side reload tracker for an Android. */
    private static boolean reloadAndroid(Mob android) {
        InteractionHand hand;
        ItemStack stack;
        if (isNtglWeapon(android.getMainHandItem())) {
            hand = InteractionHand.MAIN_HAND;
            stack = android.getMainHandItem();
        } else if (isNtglWeapon(android.getOffhandItem())) {
            hand = InteractionHand.OFF_HAND;
            stack = android.getOffhandItem();
        } else {
            return false;
        }

        try {
            Class<?> dataType = Class.forName(
                    "com.nukateam.ntgl.common.data.WeaponData");
            Object data = dataType.getConstructor(ItemStack.class, LivingEntity.class)
                    .newInstance(stack, android);
            Class<?> trackerType = Class.forName(
                    "com.nukateam.ntgl.common.util.trackers.ReloadTracker");
            trackerType.getMethod("startReloading", dataType, InteractionHand.class)
                    .invoke(null, data, hand);
            LOGGER.info("NTGL reload requested for Android {}", android.getUUID());
            return true;
        } catch (ReflectiveOperationException error) {
            LOGGER.warn("Could not start NTGL reload for Android", error);
            return false;
        }
    }

    private static int setNearestAircraftRole(CommandSourceStack source,
                                              AircraftRole role) {
        Entity caller = source.getEntity();
        if (!(caller instanceof Player player)) {
            source.sendFailure(Component.literal("Solo un jugador puede usar este comando."));
            return 0;
        }

        ServerLevel level = (ServerLevel) player.level();
        Mob android = level.getEntitiesOfClass(
                        Mob.class, player.getBoundingBox().inflate(8.0D),
                        candidate -> isAndroid(candidate)
                                && candidate.isPassenger()
                                && isAircraft(candidate.getVehicle()))
                .stream()
                .min(Comparator.comparingDouble((Mob candidate) -> player.distanceToSqr(candidate)))
                .orElse(null);
        if (android == null) {
            source.sendFailure(Component.literal(
                    "No hay un Android montado en un avion cerca."));
            return 0;
        }

        aircraftRoles.put(android.getUUID(), role);
        android.getPersistentData().putString(AIR_ROLE_TAG,
                role.name().toLowerCase(java.util.Locale.ROOT));
        rememberOwner(android, player);
        source.sendSuccess(() -> Component.literal(
                "Rol aereo: " + role.name().toLowerCase()), true);
        return 1;
    }

    private static boolean isAndroid(Entity entity) {
        Class<?> type = entity.getClass();
        while (type != null) {
            if (ANDROID_BASE_CLASS.equals(type.getName())) {
                return true;
            }
            type = type.getSuperclass();
        }
        return false;
    }

    private static boolean isNtglWeapon(ItemStack stack) {
        if (stack.isEmpty()) {
            return false;
        }
        Class<?> type = loadNtglWeaponType();
        return type != null && type.isInstance(stack.getItem());
    }

    /**
     * NTGL normally installs this goal itself every 20 ticks. Androids are
     * special entities, so install the same goal immediately as a fallback.
     * This also removes the dependency on Forge event listener order.
     */
    private static void ensureGunAttackGoal(Mob mob) {
        if (!(mob instanceof PathfinderMob pathfinder)) {
            return;
        }

        for (WrappedGoal wrapped : pathfinder.goalSelector.getAvailableGoals()) {
            Goal goal = wrapped.getGoal();
            if (NTGL_GOAL_CLASS.equals(goal.getClass().getName())) {
                return;
            }
        }

        try {
            Class<?> goalType = Class.forName(NTGL_GOAL_CLASS);
            Object goal = goalType.getConstructor(
                            PathfinderMob.class, double.class, float.class, float.class)
                    .newInstance(pathfinder, 1.0D, 1.0F, 30.0F);
            pathfinder.goalSelector.addGoal(2, (Goal) goal);
            LOGGER.info("NTGL GunAttackGoal attached to Android {}", mob.getUUID());
        } catch (ReflectiveOperationException | ClassCastException error) {
            LOGGER.warn("Could not attach NTGL GunAttackGoal to Android", error);
        }
    }

    /** NTGL's goal can be blocked by CC:Androids' own movement goals. */
    private static void directGroundShot(Mob android, LivingEntity target) {
        if (!(android instanceof PathfinderMob)
                || !isValidTarget(android, target)
                || !isNtglWeapon(android.getMainHandItem())) {
            return;
        }

        long now = android.level().getGameTime();
        Long next = groundNextFire.get(android.getUUID());
        if (next != null && now < next) {
            return;
        }

        try {
            aimWithVariableAccuracy(android, target);
            Class<?> goalType = Class.forName(NTGL_GOAL_CLASS);
            Method shoot = goalType.getMethod("shoot", LivingEntity.class, InteractionHand.class);
            shoot.invoke(null, android, InteractionHand.MAIN_HAND);
            groundNextFire.put(android.getUUID(), now + DIRECT_GROUND_FIRE_COOLDOWN);
            LOGGER.debug("NTGL direct ground shot for Android {} at {}",
                    android.getUUID(), target.getType().toString());
        } catch (ReflectiveOperationException | RuntimeException error) {
            LOGGER.warn("Could not fire NTGL weapon from Android", error);
        }
    }

    private static void aimWithVariableAccuracy(Mob android, LivingEntity target) {
        Vec3 origin = android.getEyePosition(1.0F);
        Vec3 wanted = target.getEyePosition(1.0F).subtract(origin).normalize();
        double spread = (1.0D - accuracyFor(android)) * 0.35D;
        var random = android.getRandom();
        Vec3 noisy = wanted.add(
                (random.nextDouble() - 0.5D) * spread,
                (random.nextDouble() - 0.5D) * spread,
                (random.nextDouble() - 0.5D) * spread).normalize();
        float yaw = (float) Math.toDegrees(Math.atan2(-noisy.x, noisy.z));
        float pitch = (float) Math.toDegrees(Math.asin(-noisy.y));
        android.setYRot(yaw);
        android.setXRot(pitch);
        android.setYHeadRot(yaw);
        android.setYBodyRot(yaw);
    }

    /** GunAttackGoal only reads the main hand, so normalize CC:Androids equipment. */
    private static void moveNtglWeaponToMainHand(Mob android) {
        if (isNtglWeapon(android.getMainHandItem())
                || !isNtglWeapon(android.getOffhandItem())) {
            return;
        }

        ItemStack main = android.getMainHandItem();
        ItemStack offhand = android.getOffhandItem();
        android.setItemInHand(InteractionHand.MAIN_HAND, offhand);
        android.setItemInHand(InteractionHand.OFF_HAND, main);
        LOGGER.info("Moved NTGL weapon to Android main hand {}", android.getUUID());
    }

    /**
     * Reloads an empty NTGL weapon from the Android inventory.
     *
     * The old implementation called setMaxAmmo() unconditionally.  That made
     * every Android effectively creative: it received a new full magazine
     * without consuming any cartridge.  NTGL already knows which ammo item is
     * valid for the weapon, so use its InventoryUtil/AmmoContext to consume
     * real items from the Android's SimpleContainer and only load the amount
     * that was actually found.
     */
    private static void ensureAutomaticReload(Mob mob, ItemStack weapon) {
        try {
            Class<?> dataType = Class.forName(NTGL_WEAPON_DATA_CLASS);
            Object data = dataType.getConstructor(ItemStack.class, LivingEntity.class)
                    .newInstance(weapon, mob);

            // GunAttackGoal and EntityReloadTracker always use PRIMARY.  Set it
            // explicitly as well: some NTGL weapons keep AmmoCount in a nested
            // tag whose key is the selected weapon mode.
            Class<?> modeType = Class.forName(
                    "com.nukateam.ntgl.common.data.holders.WeaponMode");
            Object primary = modeType.getField("PRIMARY").get(null);
            dataType.getMethod("setWeaponMode", modeType).invoke(data, primary);

            Class<?> stateHelper = Class.forName(NTGL_STATE_HELPER_CLASS);
            int before = (Integer) stateHelper
                    .getMethod("getAmmoCount", dataType)
                    .invoke(null, data);
            int max = (Integer) Class.forName(
                    "com.nukateam.ntgl.common.util.util.WeaponModifierHelper")
                    .getMethod("getMaxAmmo", dataType)
                    .invoke(null, data);
            boolean hasAmmo = (Boolean) stateHelper
                    .getMethod("hasAmmo", dataType)
                    .invoke(null, data);
            if (hasAmmo) {
                return;
            }

            int requested = Math.max(0, max - before);
            int loaded = consumeAndroidAmmo(mob, data, requested);
            if (loaded <= 0) {
                LOGGER.debug("Android {} has no compatible NTGL ammunition for {}",
                        mob.getUUID(), BuiltInRegistries.ITEM.getKey(weapon.getItem()));
                return;
            }

            // Write only the number of rounds paid for with physical ammo.
            stateHelper.getMethod("setAmmoCount", dataType, int.class)
                    .invoke(null, data, Math.min(max, before + loaded));

            // Re-attach the same stack so NTGL sees the updated NBT even on
            // Android implementations that expose a defensive ItemStack copy.
            mob.setItemInHand(InteractionHand.MAIN_HAND, weapon);

            int after = (Integer) stateHelper
                    .getMethod("getAmmoCount", dataType)
                    .invoke(null, data);
            if (after <= 0) {
                LOGGER.warn("Automatic NTGL reload wrote no ammo for Android {} (before={}, max={}, loaded={}, after={})",
                        mob.getUUID(), before, max, loaded, after);
            } else {
                LOGGER.info("Automatic NTGL reload completed for Android {} ({} -> {}/{}, consumed={})",
                        mob.getUUID(), before, after, max, loaded);
            }
        } catch (ReflectiveOperationException | ClassCastException error) {
            LOGGER.warn("Automatic NTGL reload failed for Android", error);
        }
    }

    /**
     * Consumes compatible ammo using NTGL's own AmmoHolder rules.
     *
     * This keeps compatibility with custom ammo from NTGL and other weapon
     * mods: AmmoHolder.isAcceptable() decides what can be loaded and its
     * AmmoContext.shrink() applies the correct stack/value behaviour.
     */
    private static int consumeAndroidAmmo(Mob mob, Object data, int requested)
            throws ReflectiveOperationException {
        if (requested <= 0) {
            return 0;
        }

        SimpleContainer inventory = getAndroidInventory(mob);
        if (inventory == null) {
            return 0;
        }

        Class<?> dataType = Class.forName(NTGL_WEAPON_DATA_CLASS);
        Class<?> holderType = Class.forName(NTGL_AMMO_HOLDER_CLASS);
        Class<?> contextType = Class.forName(NTGL_AMMO_CONTEXT_CLASS);
        Class<?> inventoryUtil = Class.forName(NTGL_INVENTORY_UTIL_CLASS);

        Class<?> stateHelperType = Class.forName(NTGL_STATE_HELPER_CLASS);
        Object ammoHolder = stateHelperType
                .getMethod("getCurrentAmmoWithoutCheck", dataType)
                .invoke(null, data);
        if (ammoHolder == null) {
            return 0;
        }

        Method findAmmo = inventoryUtil.getMethod(
                "findAmmo", net.minecraft.world.Container.class, holderType);
        Method stackMethod = contextType.getMethod("stack");
        Method shrinkMethod = contextType.getMethod(
                "shrink", int.class, holderType, LivingEntity.class);

        int remaining = requested;
        int loaded = 0;
        int safety = inventory.getContainerSize() * 2 + 4;
        while (remaining > 0 && safety-- > 0) {
            Object context = findAmmo.invoke(null, inventory, ammoHolder);
            if (context == null) {
                break;
            }

            ItemStack stack = (ItemStack) stackMethod.invoke(context);
            if (stack == null || stack.isEmpty()) {
                break;
            }

            int value = (Integer) holderType
                    .getMethod("getValue", ItemStack.class)
                    .invoke(ammoHolder, stack);
            value = Math.max(1, value);
            int available = Math.max(1, stack.getCount() * value);
            int take = Math.min(remaining, available);

            shrinkMethod.invoke(context, take, ammoHolder, mob);
            loaded += take;
            remaining -= take;
        }
        inventory.setChanged();
        return loaded;
    }

    /** Equips modded armor and Curios-compatible backpacks from Android storage. */
    private static void equipArmorAndBackpack(Mob android) {
        SimpleContainer inventory = getAndroidInventory(android);
        if (inventory == null) {
            return;
        }

        for (int index = 0; index < inventory.getContainerSize(); index++) {
            ItemStack stack = inventory.getItem(index);
            if (stack.isEmpty() || !(stack.getItem() instanceof ArmorItem armor)) {
                continue;
            }

            EquipmentSlot slot = armor.getEquipmentSlot();
            if (slot.getType() == EquipmentSlot.Type.ARMOR
                    && android.getItemBySlot(slot).isEmpty()) {
                android.setItemSlot(slot, stack.copy());
                inventory.setItem(index, ItemStack.EMPTY);
                inventory.setChanged();
                LOGGER.info("Armor equipped on Android {}: {}", android.getUUID(), slot);
            }
        }

        for (int index = 0; index < inventory.getContainerSize(); index++) {
            ItemStack stack = inventory.getItem(index);
            if (!isBackpack(stack) || !equipBackpackCurio(android, stack)) {
                continue;
            }
            inventory.setItem(index, ItemStack.EMPTY);
            inventory.setChanged();
            LOGGER.info("Backpack equipped on Android {}", android.getUUID());
            break;
        }
    }

    private static SimpleContainer getAndroidInventory(Mob android) {
        try {
            Object value = android.getClass().getField("inventory").get(android);
            return value instanceof SimpleContainer container ? container : null;
        } catch (ReflectiveOperationException error) {
            LOGGER.debug("Android inventory is not accessible", error);
            return null;
        }
    }

    private static boolean isBackpack(ItemStack stack) {
        if (stack.isEmpty()) {
            return false;
        }
        String name = stack.getItem().getClass().getSimpleName().toLowerCase();
        String id = BuiltInRegistries.ITEM.getKey(stack.getItem()).toString().toLowerCase();
        return name.contains("backpack") || id.contains("backpack")
                || name.contains("rucksack") || id.contains("rucksack")
                || name.contains("satchel") || id.contains("satchel");
    }

    /** Uses Curios' back slot without a hard dependency on Curios. */
    private static boolean equipBackpackCurio(Mob android, ItemStack backpack) {
        try {
            Class<?> api = Class.forName("top.theillusivec4.curios.api.CuriosApi");
            Object lazy = api.getMethod("getCuriosInventory", LivingEntity.class)
                    .invoke(null, android);
            Object resolved = lazy.getClass().getMethod("resolve").invoke(lazy);
            if (!(resolved instanceof Optional<?> optional) || optional.isEmpty()) {
                return false;
            }

            Object handler = optional.get();
            Object slotResult = handler.getClass()
                    .getMethod("getStacksHandler", String.class)
                    .invoke(handler, "back");
            if (!(slotResult instanceof Optional<?> slotOptional)
                    || slotOptional.isEmpty()) {
                return false;
            }

            Object stacksHandler = slotOptional.get();
            Object stacks = stacksHandler.getClass().getMethod("getStacks")
                    .invoke(stacksHandler);
            int slots = (Integer) stacks.getClass().getMethod("getSlots").invoke(stacks);
            for (int index = 0; index < slots; index++) {
                ItemStack equipped = (ItemStack) stacks.getClass()
                        .getMethod("getStackInSlot", int.class)
                        .invoke(stacks, index);
                if (equipped.isEmpty()) {
                    stacks.getClass().getMethod("setStackInSlot", int.class, ItemStack.class)
                            .invoke(stacks, index, backpack.copy());
                    stacksHandler.getClass().getMethod("update").invoke(stacksHandler);
                    return true;
                }
            }
        } catch (ReflectiveOperationException | ClassCastException error) {
            LOGGER.debug("Curios backpack slot is unavailable", error);
        }
        return false;
    }

    private static Class<?> loadNtglWeaponType() {
        if (checkedNtgl) {
            return ntglWeaponType;
        }
        synchronized (AndroidsCompatMod.class) {
            if (!checkedNtgl) {
                try {
                    ntglWeaponType = Class.forName(NTGL_WEAPON_CLASS);
                    LOGGER.info("NTGL weapon interface detected");
                } catch (ClassNotFoundException ignored) {
                    LOGGER.warn("NTGL is not installed; ranged compatibility is disabled");
                }
                checkedNtgl = true;
            }
        }
        return ntglWeaponType;
    }

    private static boolean isValidTarget(Mob mob, LivingEntity target) {
        return !isSpy(mob)
                && target != null
                && target.isAlive()
                && target instanceof Enemy
                && !mob.isAlliedTo(target)
                && mob.distanceToSqr(target) <= TARGET_RANGE * TARGET_RANGE;
    }

    private static LivingEntity findNearestEnemy(Mob mob) {
        List<LivingEntity> candidates = mob.level().getEntitiesOfClass(
                LivingEntity.class,
                mob.getBoundingBox().inflate(TARGET_RANGE),
                target -> target != mob
                        && target.isAlive()
                        && !isSpy(mob)
                        && target instanceof Enemy
                        && !(target instanceof Player)
                        && !mob.isAlliedTo(target));

        return candidates.stream()
                .min(Comparator.comparingDouble(mob::distanceToSqr))
                .orElse(null);
    }
}
