package com.puentenorte.androidscompat;

import com.mojang.blaze3d.platform.InputConstants;
import net.minecraft.client.KeyMapping;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.client.gui.components.Button;
import net.minecraft.network.chat.Component;
import net.minecraftforge.client.event.RegisterKeyMappingsEvent;
import net.minecraftforge.client.settings.KeyConflictContext;
import net.minecraftforge.event.TickEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;
import org.lwjgl.glfw.GLFW;

/** Client-only command console. The server remains authoritative. */
public final class CommanderClient {
    public static final KeyMapping COMMANDER_KEY = new KeyMapping(
            "key.androidscompat.commander",
            KeyConflictContext.IN_GAME,
            InputConstants.Type.KEYSYM,
            GLFW.GLFW_KEY_G,
            "key.categories.androidscompat");

    private CommanderClient() {
    }

    @Mod.EventBusSubscriber(modid = AndroidsCompatMod.MOD_ID,
            value = net.minecraftforge.api.distmarker.Dist.CLIENT,
            bus = Mod.EventBusSubscriber.Bus.MOD)
    public static final class Registration {
        private Registration() {
        }

        @SubscribeEvent
        public static void registerKey(RegisterKeyMappingsEvent event) {
            event.register(COMMANDER_KEY);
        }
    }

    @Mod.EventBusSubscriber(modid = AndroidsCompatMod.MOD_ID,
            value = net.minecraftforge.api.distmarker.Dist.CLIENT)
    public static final class ClientEvents {
        private ClientEvents() {
        }

        @SubscribeEvent
        public static void onClientTick(TickEvent.ClientTickEvent event) {
            if (event.phase != TickEvent.Phase.END) {
                return;
            }
            Minecraft minecraft = Minecraft.getInstance();
            if (COMMANDER_KEY.consumeClick()
                    && minecraft.player != null
                    && minecraft.screen == null) {
                minecraft.setScreen(new CommanderScreen());
            }
        }
    }

    private static final class CommanderScreen extends Screen {
        private Component lastAction = Component.literal(
                "Pulsa un boton para enviar una orden");

        private CommanderScreen() {
            super(Component.literal("Comandante AndroidsCompat"));
        }

        @Override
        protected void init() {
            int left = this.width / 2 - 198;
            int right = this.width / 2 + 8;
            int top = 34;
            int row = 0;
            add(left, top, "IA: activar", "!androidscompat commander on", row++);
            add(right, top, "IA: desactivar", "!androidscompat commander off", row - 1);
            add(left, top, "Patrulla", "!androidscompat order all patrol", row++);
            add(right, top, "Mantener posicion", "!androidscompat order all hold", row - 1);
            add(left, top, "Regresar a base", "!androidscompat order all return", row++);
            add(right, top, "Defender zona", "!androidscompat order all guard", row - 1);
            add(left, top, "Logistica", "!androidscompat order all logistics", row++);
            add(right, top, "Recargar armas", "!androidscompat reload", row - 1);
            add(left, top, "Piloto de combate", "!androidscompat autopilot combat", row++);
            add(right, top, "Bombardero", "!androidscompat autopilot bomber", row - 1);
            add(left, top, "Transporte", "!androidscompat autopilot transport", row++);
            add(right, top, "Capturar", "!androidscompat capture", row - 1);
            add(left, top, "Encarcelar", "!androidscompat imprison", row++);
            add(right, top, "Liberar", "!androidscompat release", row - 1);
            add(left, top, "Espia: activar", "!androidscompat spy on", row++);
            add(right, top, "Espia: desactivar", "!androidscompat spy off", row - 1);
            add(left, top, "Informe intel", "!androidscompat intel", row++);
            add(right, top, "Ayuda completa", "!help list", row - 1);
            add(left, top, "Estado del comandante", "!androidscompat commander status", row++);
            add(right, top, "Cerrar", null, row - 1);
        }

        private void add(int x, int top, String label, String command, int row) {
            int y = top + row * 22;
            addRenderableWidget(Button.builder(Component.literal(label), button -> {
                if (command == null) {
                    onClose();
                    return;
                }
                sendChat(command);
                lastAction = Component.literal("Enviado: " + label);
            }).bounds(x, y, 190, 20).build());
        }

        private void sendChat(String command) {
            Minecraft minecraft = Minecraft.getInstance();
            if (minecraft.player != null && minecraft.player.connection != null) {
                minecraft.player.connection.sendChat(command);
            }
        }

        @Override
        public void render(GuiGraphics graphics, int mouseX, int mouseY,
                           float partialTick) {
            renderBackground(graphics);
            graphics.drawCenteredString(this.font, this.title,
                    this.width / 2, 12, 0xFFFFFF);
            graphics.drawCenteredString(this.font, lastAction,
                    this.width / 2, this.height - 22, 0xA0A0A0);
            super.render(graphics, mouseX, mouseY, partialTick);
        }

        @Override
        public boolean isPauseScreen() {
            return false;
        }
    }
}
