import java.applet.*;

public class tattler extends Applet {
	public void init() {
		new tattleClientThread(this).start();
	}
}
