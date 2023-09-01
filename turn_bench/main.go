// SPDX-FileCopyrightText: 2023 The Pion community <https://pion.ly>
// SPDX-License-Identifier: MIT

// Package main implements a TURN client using UDP
package main

import (
	"crypto/rand"
	"flag"
	"fmt"
	"log"
	"net"
	"strings"
	"time"

	"github.com/pion/logging"
	"github.com/pion/turn/v2"
)

func main() {
	host := flag.String("host", "", "TURN Server name.")
	port := flag.Int("port", 3478, "Listening port.")
	user := flag.String("user", "", "A pair of username and password (e.g. \"user=pass\")")
	realm := flag.String("realm", "pion.ly", "Realm (defaults to \"pion.ly\")")
	bitrate := flag.Int("bitrate", 50, "bitrate in kbps")
	dur := flag.Int("duration", 30, "time in seconds")
	packetSize := flag.Int("packetSize", 50, "UDP datagram size in bytes")

	flag.Parse()

	if len(*host) == 0 {
		log.Fatalf("'host' is required")
	}

	if len(*user) == 0 {
		log.Fatalf("'user' is required")
	}

	cred := strings.SplitN(*user, "=", 2)

	// TURN client won't create a local listening socket by itself.
	conn, err := net.ListenPacket("udp4", "0.0.0.0:0")
	if err != nil {
		log.Panicf("Failed to listen: %s", err)
	}
	defer func() {
		if closeErr := conn.Close(); closeErr != nil {
			log.Panicf("Failed to close connection: %s", closeErr)
		}
	}()

	turnServerAddr := fmt.Sprintf("%s:%d", *host, *port)

	cfg := &turn.ClientConfig{
		STUNServerAddr: turnServerAddr,
		TURNServerAddr: turnServerAddr,
		Conn:           conn,
		Username:       cred[0],
		Password:       cred[1],
		Realm:          *realm,
		LoggerFactory:  logging.NewDefaultLoggerFactory(),
	}

	client, err := turn.NewClient(cfg)
	if err != nil {
		log.Panicf("Failed to create TURN client: %s", err)
	}
	defer client.Close()

	// Start listening on the conn provided.
	err = client.Listen()
	if err != nil {
		log.Panicf("Failed to listen: %s", err)
	}

	// Allocate a relay socket on the TURN server. On success, it
	// will return a net.PacketConn which represents the remote
	// socket.
	relayConn, err := client.Allocate()
	if err != nil {
		log.Panicf("Failed to allocate: %s", err)
	}
	defer func() {
		if closeErr := relayConn.Close(); closeErr != nil {
			log.Panicf("Failed to close connection: %s", closeErr)
		}
	}()

	// The relayConn's local address is actually the transport
	// address assigned on the TURN server.
	log.Printf("relayed-address=%s", relayConn.LocalAddr().String())

	err = doPingTest(client, relayConn, *bitrate, *dur, *packetSize)
	if err != nil {
		log.Panicf("Failed to ping: %s", err)
	}
}

func doPingTest(client *turn.Client, relayConn net.PacketConn, bitrate int, dur int, packetSize int) error {
	// Send BindingRequest to learn our external IP
	mappedAddr, err := client.SendBindingRequest()
	if err != nil {
		return err
	}

	// Set up pinger socket (pingerConn)
	pingerConn, err := net.ListenPacket("udp4", "0.0.0.0:0")
	if err != nil {
		log.Panicf("Failed to listen: %s", err)
	}
	defer func() {
		if closeErr := pingerConn.Close(); closeErr != nil {
			log.Panicf("Failed to close connection: %s", closeErr)
		}
	}()

	// Punch a UDP hole for the relayConn by sending a data to the mappedAddr.
	// This will trigger a TURN client to generate a permission request to the
	// TURN server. After this, packets from the IP address will be accepted by
	// the TURN server.
	_, err = relayConn.WriteTo([]byte("Hello"), mappedAddr)
	if err != nil {
		return err
	}

	// Start read-loop on pingerConn
	go func() {
		buf := make([]byte, 1600)
		for {
			_, _, pingerErr := pingerConn.ReadFrom(buf)
			if pingerErr != nil {
				break
			}

			// log.Printf("%d bytes from %s \n", n, from.String())
		}
	}()

	// Start read-loop on relayConn
	go func() {
		buf := make([]byte, 1600)
		for {
			n, from, readerErr := relayConn.ReadFrom(buf)
			if readerErr != nil {
				break
			}

			// Echo back
			if _, readerErr = relayConn.WriteTo(buf[:n], from); readerErr != nil {
				break
			}
		}
	}()

	time.Sleep(500 * time.Millisecond)

	// calculate how many packets we need to send and their interval
	// we add 8 for UDP datagram header and 20 for ip packet header
	numOfPacketsToSend := bitrate * 1000 * dur / ((packetSize + 20 + 8) * 8)
	interval := dur * 1000 / numOfPacketsToSend

	// prepare random data
	buf := make([]byte, packetSize)
	_, err = rand.Read(buf)
	if err != nil {
		return err
	}

	for i := 0; i < numOfPacketsToSend; i++ {

		_, err = pingerConn.WriteTo(buf, relayConn.LocalAddr())
		if err != nil {
			return err
		}

		time.Sleep(time.Duration(interval) * time.Millisecond)
	}

	return nil
}
