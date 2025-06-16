package com.rubdev.zebrautil;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.ColorMatrix;
import android.graphics.ColorMatrixColorFilter;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.location.LocationManager;
import android.os.Build;
import android.os.Looper;
import android.util.Base64;

import androidx.annotation.NonNull;

import com.zebra.sdk.comm.BluetoothConnection;
import com.zebra.sdk.comm.Connection;
import com.zebra.sdk.comm.ConnectionException;
import com.zebra.sdk.comm.TcpConnection;
import com.zebra.sdk.printer.ZebraPrinter;
import com.zebra.sdk.printer.ZebraPrinterFactory;
import com.zebra.sdk.printer.ZebraPrinterLanguageUnknownException;
import com.zebra.sdk.printer.discovery.DiscoveredPrinter;
import com.zebra.sdk.printer.discovery.NetworkDiscoverer;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Objects;

import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

public class Printer implements MethodChannel.MethodCallHandler {

    private static final int ACCESS_COARSE_LOCATION_REQUEST_CODE = 100021;
    private static final int ON_DISCOVERY_ERROR_GENERAL = -1;
    private static final int ON_DISCOVERY_ERROR_BLUETOOTH = -2;
    private static final int ON_DISCOVERY_ERROR_LOCATION = -3;
    private Connection printerConnection;
    private ZebraPrinter printer;
    private Context context;
    private ActivityPluginBinding binding;
    private MethodChannel methodChannel;
    private String selectedAddress = null;
    private String macAddress = null;
    private boolean tempIsPrinterConnect;
    private static ArrayList<DiscoveredPrinter> discoveredPrinters = new ArrayList<>();
    private static ArrayList<DiscoveredPrinter> sendedDiscoveredPrinters = new ArrayList<>();
    private boolean isZebraPrinter = true;
    private Socketmanager socketmanager;
    private static boolean isBluetoothDiscoveryActive = false;
    private static boolean isNetworkDiscoveryActive = false;
    private static int activeDiscoveryCount = 0;


    public Printer(ActivityPluginBinding binding, BinaryMessenger binaryMessenger) {
        this.context = binding.getActivity();
        this.binding = binding;
        this.methodChannel = new MethodChannel(binaryMessenger, "ZebraPrinterObject" + this);
        methodChannel.setMethodCallHandler(this);
    }


    public static void startScanning(final Context context, final MethodChannel methodChannel) {

        try {
            System.out.println("ZebraUtil: Starting printer discovery...");
            sendedDiscoveredPrinters.clear();
            for (DiscoveredPrinter dp :
                    discoveredPrinters) {
                addNewDiscoverPrinter(dp, context, methodChannel);
            }
            // Start Network discovery
            System.out.println("ZebraUtil: Starting Network discovery...");
            isNetworkDiscoveryActive = true;
            activeDiscoveryCount++;
            NetworkDiscoverer.findPrinters(new DiscoveryHandlerCustom() {
                @Override
                public void foundPrinter(DiscoveredPrinter discoveredPrinter) {
                    System.out.println("ZebraUtil: Network printer found: " + discoveredPrinter.address);
                    addNewDiscoverPrinter(discoveredPrinter, context, methodChannel);
                }

                @Override
                public void printerOutOfRange(DiscoveredPrinter discoverPrinter) {
                    System.out.println("ZebraUtil: Network printer out of range: " + discoverPrinter.address);
                    removeDiscoverPrinter(discoverPrinter,context,methodChannel);
                }

                @Override
                public void discoveryFinished() {
                    System.out.println("ZebraUtil: Network discovery finished");
                    isNetworkDiscoveryActive = false;
                    activeDiscoveryCount--;
                    if (activeDiscoveryCount == 0) {
                        System.out.println("ZebraUtil: All discovery finished");
                        onDiscoveryDone(context, methodChannel);
                    }
                }

                @Override
                public void discoveryError(String s) {
                    System.out.println("ZebraUtil: Network discovery error: " + s);
                    isNetworkDiscoveryActive = false;
                    activeDiscoveryCount--;
                    onDiscoveryError(context, methodChannel, ON_DISCOVERY_ERROR_GENERAL, s);
                }
            });
            
            // Start Bluetooth discovery
            System.out.println("ZebraUtil: Starting Bluetooth discovery...");
            isBluetoothDiscoveryActive = true;
            activeDiscoveryCount++;
            BluetoothDiscoverer.findPrinters(context, new DiscoveryHandlerCustom() {
                @Override
                public void foundPrinter(final DiscoveredPrinter discoveredPrinter) {
                    System.out.println("ZebraUtil: Bluetooth printer found: " + discoveredPrinter.address);
                    discoveredPrinters.add(discoveredPrinter);
                    ((Activity) context).runOnUiThread(() -> addNewDiscoverPrinter(discoveredPrinter, context, methodChannel));
                }

                @Override
                public void printerOutOfRange(DiscoveredPrinter discoverPrinter) {
                    System.out.println("ZebraUtil: Bluetooth printer out of range: " + discoverPrinter.address);
                    removeDiscoverPrinter(discoverPrinter,context,methodChannel);
                }

                @Override
                public void discoveryFinished() {
                    System.out.println("ZebraUtil: Bluetooth discovery finished");
                    isBluetoothDiscoveryActive = false;
                    activeDiscoveryCount--;
                    if (activeDiscoveryCount == 0) {
                        System.out.println("ZebraUtil: All discovery finished");
                        onDiscoveryDone(context, methodChannel);
                    }
                }

                @Override
                public void discoveryError(String s) {
                    System.out.println("ZebraUtil: Bluetooth discovery error: " + s);
                    isBluetoothDiscoveryActive = false;
                    activeDiscoveryCount--;
                    if(s.contains("Bluetooth radio is currently disabled"))
                        onDiscoveryError(context, methodChannel, ON_DISCOVERY_ERROR_BLUETOOTH, s);
                    else
                        onDiscoveryError(context, methodChannel, ON_DISCOVERY_ERROR_GENERAL, s);
                }
            });

            
        } catch (Exception e) {
            System.out.println("ZebraUtil: Exception during discovery: " + e.getMessage());
            e.printStackTrace();
            // Reset counters on exception
            isBluetoothDiscoveryActive = false;
            isNetworkDiscoveryActive = false;
            activeDiscoveryCount = 0;
        }
    }

    private static void onDiscoveryError(Context context, final MethodChannel methodChannel, final int errorCode, final String errorText) {
        ((Activity) context).runOnUiThread(() -> {
            HashMap<String, Object> arguments = new HashMap<>();
            arguments.put("ErrorCode", errorCode);
            arguments.put("ErrorText", errorText);
            methodChannel.invokeMethod("onDiscoveryError", arguments);
        });

    }

    private static void onDiscoveryDone(Context context,final MethodChannel methodChannel){
        ((Activity) context).runOnUiThread(() -> methodChannel.invokeMethod("onDiscoveryDone",
                context.getResources().getString(R.string.done)));
    }

    private void checkPermission(Context context, final MethodChannel.Result result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            // Check for location permission (required for Bluetooth scanning)
            boolean hasLocationPermission = context.checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
                    context.checkSelfPermission(android.Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED;
            
            // Check for Bluetooth permissions (required for Android 12+)
            boolean hasBluetoothScanPermission = true;
            boolean hasBluetoothConnectPermission = true;
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                hasBluetoothScanPermission = context.checkSelfPermission(android.Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED;
                hasBluetoothConnectPermission = context.checkSelfPermission(android.Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED;
            }
            
            if (!hasLocationPermission || !hasBluetoothScanPermission || !hasBluetoothConnectPermission) {
                binding.addRequestPermissionsResultListener(new PluginRegistry.RequestPermissionsResultListener() {
                    @Override
                    public boolean onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
                        if (requestCode == ACCESS_COARSE_LOCATION_REQUEST_CODE) {
                            boolean allGranted = true;
                            for (int grantResult : grantResults) {
                                if (grantResult != PackageManager.PERMISSION_GRANTED) {
                                    allGranted = false;
                                    break;
                                }
                            }
                            try {
                                result.success(allGranted);
                                return false;
                            } catch (Exception e) {
                                return false;
                            }
                        }
                        result.success(false);
                        return false;
                    }
                });
                
                // Request all necessary permissions
                java.util.List<String> permissionsToRequest = new java.util.ArrayList<>();
                if (!hasLocationPermission) {
                    permissionsToRequest.add(android.Manifest.permission.ACCESS_FINE_LOCATION);
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    if (!hasBluetoothScanPermission) {
                        permissionsToRequest.add(android.Manifest.permission.BLUETOOTH_SCAN);
                    }
                    if (!hasBluetoothConnectPermission) {
                        permissionsToRequest.add(android.Manifest.permission.BLUETOOTH_CONNECT);
                    }
                }
                
                ((Activity) context).requestPermissions(
                    permissionsToRequest.toArray(new String[0]),
                    ACCESS_COARSE_LOCATION_REQUEST_CODE
                );
            } else {
                result.success(true);
            }
        } else {
            result.success(true);
        }
    }


    private static void addPrinterToDiscoveryPrinterList(DiscoveredPrinter discoveredPrinter) {
        for (DiscoveredPrinter dp :
                discoveredPrinters) {
            if (dp.address.equals(discoveredPrinter.address))
                return;
        }

        discoveredPrinters.add(discoveredPrinter);
    }

    private static void removePrinterToDiscoveryPrinterList(DiscoveredPrinter discoveredPrinter){
        discoveredPrinters.remove(discoveredPrinter);
    }


    private static void addNewDiscoverPrinter(final DiscoveredPrinter discoveredPrinter, Context context, final MethodChannel methodChannel) {
        addPrinterToDiscoveryPrinterList(discoveredPrinter);
        ((Activity) context).runOnUiThread(() -> {
            for (DiscoveredPrinter dp :
                    sendedDiscoveredPrinters) {
                if (dp.address.equals(discoveredPrinter.address))
                    return;
            }
            sendedDiscoveredPrinters.add(discoveredPrinter);
            HashMap<String, Object> arguments = new HashMap<>();

            arguments.put("Address", discoveredPrinter.address);
            arguments.put("Status", context.getString(R.string.disconnect));
            if (discoveredPrinter.getDiscoveryDataMap().get("SYSTEM_NAME") != null) {
                arguments.put("Name", discoveredPrinter.getDiscoveryDataMap().get("SYSTEM_NAME"));
                arguments.put("IsWifi", true);
                methodChannel.invokeMethod("printerFound"
                        , arguments);
            } else {
                arguments.put("Name", discoveredPrinter.getDiscoveryDataMap().get("FRIENDLY_NAME"));
                arguments.put("IsWifi", false);
                methodChannel.invokeMethod("printerFound"
                        , arguments);
            }
        });
    }

    private static void removeDiscoverPrinter(final DiscoveredPrinter discoveredPrinter, Context context,final MethodChannel methodChannel){

        removePrinterToDiscoveryPrinterList(discoveredPrinter);
    ((Activity) context).runOnUiThread(() -> {

        sendedDiscoveredPrinters.remove(discoveredPrinter);
        HashMap<String, Object> arguments = new HashMap<>();
        arguments.put("Address", discoveredPrinter.address);
        methodChannel.invokeMethod("printerRemoved", arguments);
    });
    }


    public void print(final String data) {
        new Thread(() -> {
            Looper.prepare();
            doConnectionTest(data);
            Looper.loop();
            Objects.requireNonNull(Looper.myLooper()).quit();
        }).start();
    }


    private void doConnectionTest(String data) {

        if (isZebraPrinter) {
            if (printer != null) {
                printData(data);
            } else {
                disconnect();
            }
        } else {
            printDataGenericPrinter(data);
        }
    }

    private void printDataGenericPrinter(String data) {
        setStatus(context.getString(R.string.sending_data), context.getString(R.string.connectingColor));
        socketmanager.threadconnectwrite(convertDataToByte(data));
        try {
            Thread.sleep(100);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        if (socketmanager.getIstate()) {
            setStatus(context.getResources().getString(R.string.done), context.getString(R.string.connectedColor));
        } else {
            setStatus(context.getResources().getString(R.string.disconnect), context.getString(R.string.disconnectColor));
        }

        byte[] sendCut = {0x0a, 0x0a, 0x1d, 0x56, 0x01};
        socketmanager.threadconnectwrite(sendCut);
        try {
            Thread.sleep(100);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        if (!socketmanager.getIstate()) {
            setStatus(context.getResources().getString(R.string.disconnect)
                    , context.getString(R.string.disconnectColor));
        }
    }

    private void printData(String data) {
        try {
            byte[] bytes = convertDataToByte(data);
            setStatus(context.getString(R.string.sending_data), context.getString(R.string.connectingColor));
            printerConnection.write(bytes);
            DemoSleeper.sleep(1500);

            if (printerConnection instanceof BluetoothConnection) {
                DemoSleeper.sleep(500);
            }
            setStatus(context.getResources().getString(R.string.done), context.getString(R.string.connectedColor));
            DemoSleeper.sleep(200);
            setStatus(context.getResources().getString(R.string.connected), context.getString(R.string.connectedColor));
        } catch (ConnectionException e) {
            disconnect();
        }
    }


    public void connectToSelectPrinter(String address) {
        isZebraPrinter = true;
        setStatus(context.getString(R.string.connecting), context.getString(R.string.connectingColor));
        selectedAddress = null;
        macAddress = null;
        boolean isBluetoothPrinter;
        if (address.contains(":")) {
            macAddress = address;
            isBluetoothPrinter = true;
        } else {
            this.selectedAddress = address;
            isBluetoothPrinter = false;
        }
        printer = connect(isBluetoothPrinter);
    }

    public String isPrinterConnect() {
        if (isZebraPrinter) {
            tempIsPrinterConnect = true;
            if (printerConnection != null && printerConnection.isConnected()) {
                new Thread(() -> {
                    try {
                        printerConnection.write("Test".getBytes());
                    } catch (ConnectionException e) {
                        e.printStackTrace();
                        disconnect();
                        tempIsPrinterConnect = false;
                    }
                }).start();
                if (tempIsPrinterConnect) {
                    setStatus(context.getString(R.string.connected), context.getString(R.string.connectedColor));
                    return context.getString(R.string.connected);
                } else {
                    setStatus(context.getString(R.string.disconnect), context.getString(R.string.disconnectColor));
                    return context.getString(R.string.disconnect);
                }
            } else {
                setStatus(context.getString(R.string.disconnect), context.getString(R.string.disconnectColor));
                return context.getString(R.string.disconnect);
            }
        } else {
            if (socketmanager != null) {
                if (socketmanager.getIstate()) {
                    setStatus(context.getString(R.string.connected), context.getString(R.string.connectedColor));
                    return context.getString(R.string.connected);
                } else {
                    setStatus(context.getString(R.string.disconnect), context.getString(R.string.disconnectColor));
                    return context.getString(R.string.disconnect);
                }
            } else {
                return context.getString(R.string.disconnect);
            }
        }
    }


    public void connectToGenericPrinter(String ipAddress) {
        this.isZebraPrinter = false;
        if (isPrinterConnect().equals(context.getString(R.string.connected))) {
            disconnect();
            setStatus(context.getString(R.string.connecting), context.getString(R.string.connectingColor));
        }
        if (socketmanager == null)
            socketmanager = new Socketmanager(context);
        socketmanager.mPort = getGenericPortNumber();
        socketmanager.mstrIp = ipAddress;
        socketmanager.threadconnect();
        try {
            Thread.sleep(100);
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
        if (socketmanager.getIstate()) {
            setStatus(context.getString(R.string.connected), context.getString(R.string.connectedColor));
        } else {
            setStatus(context.getString(R.string.disconnect), context.getString(R.string.disconnectColor));
        }
    }

    public void stopScan(){
        // Stop Bluetooth discovery
        BluetoothDiscoverer.stopBluetoothDiscovery();
        
        // Reset tracking variables
        isBluetoothDiscoveryActive = false;
        isNetworkDiscoveryActive = false;
        activeDiscoveryCount = 0;
    }


    public ZebraPrinter connect(boolean isBluetoothPrinter) {
        if (isPrinterConnect().equals(context.getString(R.string.connected))) {
            disconnect();
            setStatus(context.getString(R.string.connecting), context.getString(R.string.connectingColor));
        }

        printerConnection = null;
        if (isBluetoothPrinter) {
            printerConnection = new BluetoothConnection(getMacAddress());
        } else {
            try {

                printerConnection = new TcpConnection(getTcpAddress(), getTcpPortNumber());
            } catch (NumberFormatException e) {
                setStatus("Port Invalid", context.getString(R.string.disconnectColor));
                return null;
            }
        }
        try {
            printerConnection.open();

        } catch (ConnectionException e) {
            DemoSleeper.sleep(1000);
            disconnect();
            return null;
        }

        ZebraPrinter printer = null;

        if (printerConnection.isConnected()) {
            try {
                printer = ZebraPrinterFactory.getInstance(printerConnection);
            } catch (ConnectionException | ZebraPrinterLanguageUnknownException e) {
                DemoSleeper.sleep(1000);
                disconnect();
            }
        }
        setStatus(context.getString(R.string.connected), context.getString(R.string.connectedColor));
        return printer;
    }

    private String getMacAddress() {
        return macAddress;
    }

    private static String convertMacAddressToMacAddressApp(String macAddress) {
        return macAddress;
    }

    private String getTcpAddress() {
        return selectedAddress;
    }


    public void disconnect() {
        if (isZebraPrinter) {
            try {
                setStatus(context.getString(R.string.disconnecting), context.getString(R.string.connectingColor));
                if (printerConnection != null) {
                    printerConnection.close();
                }
            } catch (ConnectionException e) {
                e.printStackTrace();
            } finally {
                setStatus(context.getString(R.string.disconnect), context.getString(R.string.disconnectColor));
            }
        } else {
            setStatus(context.getString(R.string.disconnecting), context.getString(R.string.connectingColor));
            socketmanager.close();
            setStatus(context.getString(R.string.disconnect), context.getString(R.string.disconnectColor));
        }
    }

    private void setStatus(final String message, final String color) {
        ((Activity) context).runOnUiThread(() -> {
            HashMap<String, Object> arguments = new HashMap<>();
            arguments.put("Status", message);
            arguments.put("Color", color);
            methodChannel.invokeMethod("changePrinterStatus", arguments);
        });

    }

    private int getTcpPortNumber() {
        return 6101;
    }

    private int getGenericPortNumber() {
        return 9100;
    }

    private byte[] convertDataToByte(String data) {
        return data.getBytes();
    }

    public static String getZplCode(Bitmap bitmap, Boolean addHeaderFooter, int rotation) {
        ZPLConverter zp = new ZPLConverter();
        zp.setCompressHex(true);
        zp.setBlacknessLimitPercentage(50);
        Bitmap grayBitmap = toGrayScale(bitmap, rotation);
        return zp.convertFromImage(grayBitmap, addHeaderFooter);
    }

    public static Bitmap toGrayScale(Bitmap bmpOriginal, int rotation) {
        int width, height;
        bmpOriginal = rotateBitmap(bmpOriginal, rotation);
        height = bmpOriginal.getHeight();
        width = bmpOriginal.getWidth();
        Bitmap grayScale = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        grayScale.eraseColor(Color.WHITE);
        Canvas c = new Canvas(grayScale);
        Paint paint = new Paint();
        ColorMatrix cm = new ColorMatrix();
        cm.setSaturation(0);
        ColorMatrixColorFilter f = new ColorMatrixColorFilter(cm);
        paint.setColorFilter(f);
        c.drawBitmap(bmpOriginal, 0, 0, paint);
        return grayScale;
    }


    public static Bitmap rotateBitmap(Bitmap source, float angle) {
        Matrix matrix = new Matrix();
        matrix.postRotate(angle);
        return Bitmap.createBitmap(source, 0, 0, source.getWidth(), source.getHeight(), matrix, true);
    }

    public void setSettings(String settings) {
        print(settings);
    }

    public void setDarkness(int darkness) {
        String setting = "             ! U1 setvar \"print.tone\" \"" + darkness + "\"\n";
        setSettings(setting);
    }

    public void setMediaType(String mediaType) {
        String settings;
        if (mediaType.equals("Label")) {
            settings = "! U1 setvar \"media.type\" \"label\"\n" +
                    "             ! U1 setvar \"media.sense_mode\" \"gap\"\n" +
                    "              ~jc^xa^jus^xz";
        } else if (mediaType.equals("BlackMark")) {
            settings = "! U1 setvar \"media.type\" \"label\"\n" +
                    "             ! U1 setvar \"media.sense_mode\" \"bar\"\n" +
                    "              ~jc^xa^jus^xz";
        } else {
            settings =
                    "      ! U1 setvar \"print.tone\" \"0\"\n" +
                            "      ! U1 setvar \"media.type\" \"journal\"\n";
        }
        setSettings(settings);
    }

    private void convertBase64ImageToZPLString(String data, int rotation, MethodChannel.Result result) {
        try {
            byte[] decodedString = Base64.decode(data, Base64.DEFAULT);
            Bitmap decodedByte = BitmapFactory.decodeByteArray(decodedString, 0, decodedString.length);
            result.success(Printer.getZplCode(decodedByte, false, rotation));
        } catch (Exception e) {
            result.error("-1", "Error", null);
        }
    }

    @Override
    public void onMethodCall(@NonNull final MethodCall call, @NonNull final MethodChannel.Result result) {
        if (call.method.equals("print")) {
            print(call.argument("Data").toString());
        } else if (call.method.equals("checkPermission")) {
            checkPermission(context, result);
        } else if (call.method.equals("convertBase64ImageToZPLString")) {
            convertBase64ImageToZPLString(call.argument("Data").toString()
                    , Integer.valueOf(call.argument("rotation").toString()), result);
        } else if (call.method.equals("disconnect")) {
            new Thread(() -> {
                disconnect();
                result.success(true);
            }).start();
        } else if (call.method.equals("isPrinterConnected")) {
            result.success(isPrinterConnect());
        } else if (call.method.equals("startScan")) {
            if (checkIsLocationNetworkProviderIsOn()) {
                startScanning(context, methodChannel);
            } else {
                onDiscoveryError(context, methodChannel, ON_DISCOVERY_ERROR_LOCATION, "Your location service is off.");
            }

        } else if (call.method.equals("setMediaType")) {
            String mediaType = call.argument("MediaType");
            setMediaType(mediaType);
        } else if (call.method.equals("setSettings")) {
            String settingCommand = call.argument("SettingCommand");
            setSettings(settingCommand);
        } else if (call.method.equals("setDarkness")) {
            int darkness = call.argument("Darkness");
            setDarkness(darkness);
        } else if (call.method.equals("connectToPrinter")) {
            new Thread(() -> {
                connectToSelectPrinter(call.argument("Address").toString());
                ((Activity) context).runOnUiThread(() -> result.success(true));
            }).start();

        } else if (call.method.equals("connectToGenericPrinter")) {
            connectToGenericPrinter(call.argument("Address").toString());
        } else if (call.method.equals("stopScan")) {
            stopScan();
        } else if (call.method.equals("getLocateValue")){
            String resourceKey = call.argument("ResourceKey");
            @SuppressLint("DiscouragedApi") int resId = context.getResources().getIdentifier(resourceKey, "string", context.getPackageName());
            result.success(resId == 0 ? "" : context.getString(resId));
        }else {
            result.notImplemented();
        }
    }

    private boolean checkIsLocationNetworkProviderIsOn() {
        LocationManager lm = (LocationManager) context.getSystemService(Context.LOCATION_SERVICE);
        try {
            return lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER);
        } catch (Exception ex) {
            return false;
        }
    }
}