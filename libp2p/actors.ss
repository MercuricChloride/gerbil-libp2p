(import :std/actor
        :std/logger
        :std/sugar
        :std/io
        :std/contract
        :std/text/utf8)

(start-logger!)
(current-logger-options 3)

(defmessage !connect (address))
(defmessage !listen (address))
;; Sends a message to the node we connected to
(defmessage !send (message))

(def (do-multistream-select address)
  (using (sock (tcp-connect address) :- StreamSocket)
    (let* ((reader (open-string-reader (sock.reader)))
           (writer (open-string-writer (sock.writer)))
           (wrote (StringWriter-write-string writer "/multistream/1.0.0"))
           (_ (StringWriter-close writer))
           (output-str (make-string 20))
           (read (StringReader-read-string reader output-str))
           (_ (StringReader-close reader)))
      (debugf "READ: ~a" output-str)
      (debugf "WROTE BYTES: ~a" wrote)
      (Closer-close sock)
      (debugf "Socket shutdown gracefully"))))

(def (multistream-select-handler cli)
  (let ((reader (open-string-reader (StreamSocket-reader cli)))
        (writer (open-string-writer (StreamSocket-writer cli)))
        (output-str (make-string 20)))
    (StringWriter-write-string writer "/multistream/1.0.0")
    (StringWriter-close writer)
    (StringReader-read-string reader output-str)
    (StringReader-close reader)
    (debugf "OUTPUT-STR: ~a" output-str)
    (Closer-close cli)))

(def (tcp-server srv)
  (let lp ()
    (try
     (let (cli (ServerSocket-accept srv))
       (spawn/name 'multistream-select-handler multistream-select-handler cli)
       (lp))
     (catch (e)
       (debugf "Couldn't accept socket connection, maybe closed")))))

;; A tcp actor is a kind of actor, that allows us to start a tcp-server
;; on a port, as well as connect to other tcp-servers
(def (tcp-actor)
  (while #t
    (<- ((!connect address)
         (spawn/name 'multistream-connection do-multistream-select address)
         (--> (!ok "connectin")))

        ((!listen address)
         (spawn/name 'tcp-multistream-server tcp-server (tcp-listen address))
         (--> (!ok "listenin")))

        ((!send message)
         (--> (!ok "swag"))))))

(defcall-actor (listen node address)
  (->> node (!listen address))
  error: "tcp-listen failed!")

(defcall-actor (connect node address)
  (->> node (!connect address))
  error: "tcp-connect failed!")

(defcall-actor (send node message)
  (->> node (!send message))
  error: "send failed!")

(def node-a (spawn/name 'node-a tcp-actor))
(def node-b (spawn/name 'node-b tcp-actor))

(listen node-a "127.0.0.1:3333")
(connect node-b "127.0.0.1:3333")

;;(accept node-a)
;;(read node-a)




;;(send node-a "Hello")
;;(read node-b)
;;(reader node-a)
;; (def (echo-server srv)
;;   (let lp ()
;;     (try
;;      (let (cli (ServerSocket-accept srv))
;;        (spawn/name 'echo-server-handler echo-server-handler cli)
;;        (lp))
;;      (catch (e)
;;        (debugf "Couldn't accept socket connection, maybe closed?")))))

;; (def (echo-server-handler cli)
;;   (let ((reader (StreamSocket-reader cli))
;;         (writer (StreamSocket-writer cli)))
;;     (io-copy! reader writer)
;;     (Reader-close reader)
;;     (Writer-close writer)))

;; (def (do-echo sock msg (timeo-in #f))
;;   (let* ((input (string->utf8 msg))
;;          (_ (when timeo-in
;;               (StreamSocket-set-input-timeout! sock timeo-in)))
;;          (reader (StreamSocket-reader sock))
;;          (writer (StreamSocket-writer sock))
;;          (wrote (Writer-write writer input))
;;          (_ (Writer-close writer))
;;          (buffer (make-u8vector wrote))
;;          (read (Reader-read reader buffer 0 wrote wrote))
;;          (_ (Reader-close reader))
;;          )
;;     (utf8->string buffer)))

;; (def example-input "Hello world!")
;; (def echo-server-address "127.0.0.1:3333")
;; (def srv (tcp-listen echo-server-address))
;; (def server (spawn/name 'echo-server echo-server srv))
;; (def cli (tcp-connect echo-server-address))
;; (do-echo cli "heyo")
;; (Socket-close srv)
;; (Socket-close cli)
