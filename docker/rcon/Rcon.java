import java.io.DataInputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.net.Socket;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

/**
 * Cliente RCON minimo (protocolo Source RCON usado pelo Minecraft).
 * Uso: rcon <comando...>
 */
public class Rcon {

    private static final int TYPE_AUTH = 3;
    private static final int TYPE_COMMAND = 2;

    record Packet(int id, String body) {}

    public static void main(String[] args) throws Exception {
        if (args.length == 0) {
            System.err.println("Uso: rcon <comando>");
            System.exit(2);
        }
        String password = Files.readString(Path.of("/run/secrets/minecraft_rcon_password")).trim();

        try (Socket socket = new Socket("127.0.0.1", 25575)) {
            socket.setSoTimeout(60_000);
            DataInputStream in = new DataInputStream(socket.getInputStream());
            OutputStream out = socket.getOutputStream();

            send(out, 1, TYPE_AUTH, password);
            if (read(in).id() == -1) {
                System.err.println("ERRO: senha RCON invalida");
                System.exit(1);
            }

            send(out, 2, TYPE_COMMAND, String.join(" ", args));
            String body = read(in).body().replaceAll("§.", "");
            if (!body.isEmpty()) {
                System.out.println(body);
            }
        }
    }

    private static void send(OutputStream out, int id, int type, String body) throws IOException {
        byte[] payload = body.getBytes(StandardCharsets.UTF_8);
        ByteBuffer buffer = ByteBuffer.allocate(14 + payload.length).order(ByteOrder.LITTLE_ENDIAN);
        buffer.putInt(10 + payload.length).putInt(id).putInt(type).put(payload).put((byte) 0).put((byte) 0);
        out.write(buffer.array());
        out.flush();
    }

    private static Packet read(DataInputStream in) throws IOException {
        int length = Integer.reverseBytes(in.readInt());
        byte[] data = new byte[length];
        in.readFully(data);
        ByteBuffer buffer = ByteBuffer.wrap(data).order(ByteOrder.LITTLE_ENDIAN);
        int id = buffer.getInt();
        return new Packet(id, new String(data, 8, length - 10, StandardCharsets.UTF_8));
    }
}
