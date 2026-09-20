import sqlite3
import json
import zipfile
import os
import struct
import math
import re
import glob
import pdfplumber

def text_to_embedding(text):
    embedding = model.encode(
        str(text),
        normalize_embeddings=True
    )

    return struct.pack(
        f"{len(embedding)}f",
        *embedding
    )
test_emb = model.encode("test")
print("Embedding dimension:", len(test_emb))

def chunk_text(text, chunk_words=80, overlap_words=15):
    if not text:
        return []
    # Safe word splitting using regex to avoid method-shadowing errors
    words = re.findall(r'\S+', str(text))
    if not words:
        return []
    chunks = []
    for i in range(0, len(words), chunk_words - overlap_words):
        chunk = " ".join(words[i:i + chunk_words])
        if len(chunk.strip()) > 30:
            chunks.append(chunk)
    return chunks

def main():
    os.makedirs("assets/sample", exist_ok=True)
    db_path = "assets/sample/emergency_demo_knowledge.db"
    pack_path = "assets/sample/emergency_demo.edgepack"

    if os.path.exists(db_path):
        os.remove(db_path)
    if os.path.exists(pack_path):
        os.remove(pack_path)

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    cursor.execute("""
    CREATE TABLE documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        filename TEXT NOT NULL,
        file_hash TEXT NOT NULL UNIQUE,
        file_type TEXT,
        page_count INTEGER DEFAULT 1,
        chunk_count INTEGER DEFAULT 0,
        date_added TEXT,
        file_size INTEGER DEFAULT 0
    );
    """)

    cursor.execute("""
    CREATE TABLE chunks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        doc_id INTEGER NOT NULL,
        chunk_index INTEGER NOT NULL,
        page_num INTEGER DEFAULT 1,
        content TEXT NOT NULL,
        embedding BLOB,
        FOREIGN KEY(doc_id) REFERENCES documents(id) ON DELETE CASCADE
    );
    """)

    # 1. Base Core Medical SOPs
    docs_data = [
        {
            "filename": "Heat_Stroke_Emergency_SOP.pdf",
            "file_hash": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            "file_type": "pdf", "page_count": 2, "file_size": 24500,
            "chunks": [
                (1, "Heat stroke is an acute life-threatening medical emergency defined by a core body temperature exceeding 40°C (104°F) accompanied by central nervous system dysfunction such as confusion, delirium, seizures, or coma."),
                (1, "Immediate rapid cooling is the single most critical intervention for heat stroke. Move victim immediately into cool shade or air conditioning. Strip unnecessary clothing."),
                (1, "The gold standard for heat stroke cooling is cold water immersion or ice water bath. If a tub is unavailable, aggressively douse the entire body with cool water and fan continuously."),
                (2, "Place ice packs or cold wet towels in areas with major superficial blood vessels: the groin, armpits (axillae), and sides of the neck to accelerate conductive cooling."),
                (2, "Do not administer oral fluids, aspirin, or acetaminophen to an individual with heat stroke. If the patient has altered mental status, oral fluids can lead to fatal pulmonary aspiration."),
                (2, "Monitor vital signs and stop active chilling once body temperature drops to 38.5°C (101.3°F) to prevent hypothermic overshoot and shivering."),
            ]
        },
        {
            "filename": "Severe_Bleeding_And_Tourniquet_Protocol.pdf",
            "file_hash": "7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069",
            "file_type": "pdf", "page_count": 2, "file_size": 31200,
            "chunks": [
                (1, "Uncontrolled hemorrhage is the leading cause of preventable trauma death. Arterial bleeding presents as pulsating, bright red spurts, whereas venous bleeding flows steadily."),
                (1, "First-line control for active bleeding is firm, continuous direct pressure directly over the bleeding site using sterile gauze, clean cloth, or gloved hands for at least 3-5 minutes."),
                (1, "For deep cavity or junctional wounds where direct pressure fails, perform wound packing by packing sterile hemostatic gauze tightly into the wound cavity until packed firmly against bone."),
                (2, "Apply a commercial windlass tourniquet (such as CAT) for severe extremity hemorrhage 2 to 3 inches proximal to the wound site, avoiding joints."),
                (2, "Turn the tourniquet windlass rod until the bright red bleeding completely ceases and the distal pulse is no longer palpable, then lock the windlass securely into the clip."),
                (2, "Clearly mark the application time (e.g., T=14:30) on the tourniquet band or the victim's forehead. Never loosen or remove a tourniquet in the field without surgical capability."),
            ]
        },
        {
            "filename": "Adult_CPR_And_Choking_AED.pdf",
            "file_hash": "6b86b273ff34fce19d6b804eff5a3f5747ada4eaa22f1d49c01e52ddb7875b4b",
            "file_type": "pdf", "page_count": 2, "file_size": 28900,
            "chunks": [
                (1, "Assess responsiveness: tap victim's shoulder and shout. Check for carotid pulse and normal chest rise for no more than 10 seconds. If absent, initiate cardiopulmonary resuscitation."),
                (1, "Chest compressions: Place heel of one hand in center of victim's chest on lower half of sternum. Interlock fingers. Position shoulders directly over hands with arms locked straight."),
                (1, "Compress chest at a rate of 100 to 120 compressions per minute to a depth of at least 5 cm (2 inches). Allow complete chest recoil between compressions without leaning."),
                (2, "Compression-to-ventilation ratio for adult CPR is 30 compressions followed by 2 rescue breaths, each delivered over 1 second with visible chest rise. Hands-only CPR is recommended if untrained."),
                (2, "Deploy Automated External Defibrillator (AED) immediately upon arrival. Apply pads to bare chest (upper right, lower left) and follow voice prompts. Ensure nobody touches victim during shock."),
                (2, "For conscious adult foreign-body airway obstruction (choking), deliver 5 firm back blows between shoulder blades followed by 5 quick inward and upward abdominal thrusts (Heimlich)."),
            ]
        },
        {
            "filename": "Thermal_Burns_And_Trauma_Management.pdf",
            "file_hash": "d4735e3a265e16eee03f59718b9b5d03019c07d8b6c51f90da3a666eec13ab35",
            "file_type": "pdf", "page_count": 2, "file_size": 22100,
            "chunks": [
                (1, "Thermal burn classification: First-degree (epidermis, red, painful), Second-degree (dermis, blisters, severe pain), Third-degree (full thickness, charred/white, painless due to nerve loss)."),
                (1, "Immediate first aid: Stop the burning process. Cool thermal burn with clean, cool running tap water for 10 to 20 minutes. Early cooling preserves viable tissue and reduces depth."),
                (1, "Crucial warning: Never apply ice, iced water, butter, oil, or toothpaste to burn wounds. Ice causes vasoconstriction and exacerbates local tissue ischemia and hypothermia."),
                (2, "Gently remove rings, bracelets, watches, and tight clothing from burned areas before severe swelling develops. Do not force clothing that is adhered directly to melted skin."),
                (2, "Cover the cooled burn loosely with a clean, dry, non-adherent sterile dressing or clean plastic wrap. Do not rupture or pop blisters as intact skin provides a sterile infection barrier."),
                (2, "For chemical burns, brush away dry chemical powder before irrigating with massive amounts of running water for at least 20 continuous minutes. Seek immediate trauma care."),
            ]
        },
        {
            "filename": "Head_Injury_And_Concussion_SOP.pdf",
            "file_hash": "a1b2c3d4e5f67890123456789abcdef0123456789abcdef0123456789abcdef",
            "file_type": "pdf", "page_count": 2, "file_size": 26400,
            "chunks": [
                (1, "Head injury management: Assess airway, breathing, and circulation (ABCs) while maintaining strict cervical spine stabilization if trauma or fall is suspected."),
                (1, "Signs of acute concussion or traumatic brain injury include temporary loss of consciousness, confusion, dizziness, persistent headache, vomiting, or unequal pupil size."),
                (1, "Immediate action for head trauma: Keep the victim lying still with head and shoulders slightly elevated unless spinal injury is suspected. Do not move the neck."),
                (2, "Red flag symptoms requiring emergency transport: Clear fluid or blood draining from nose or ears, worsening confusion, seizures, slurred speech, or persistent vomiting."),
                (2, "Do not apply direct pressure over a suspected skull fracture (depressed area or visible bone). Apply sterile dressing gently around the wound edges to control bleeding."),
                (2, "Monitor responsiveness using AVPU scale (Alert, Voice, Pain, Unresponsive) every 5 minutes. Keep victim warm and calm while awaiting professional emergency assistance."),
            ]
        }
    ]

    total_chunks = 0
    total_docs = 0

    # Ingest core static SOPs
    for doc in docs_data:
        cursor.execute(
            "INSERT INTO documents (filename, file_hash, file_type, page_count, chunk_count, date_added, file_size) VALUES (?, ?, ?, ?, ?, ?, ?)",
            (doc["filename"], doc["file_hash"], doc["file_type"], doc["page_count"], len(doc["chunks"]), "2026-09-05", doc["file_size"])
        )
        doc_id = cursor.lastrowid
        total_docs += 1

        for idx, (page, chunk_text_val) in enumerate(doc["chunks"]):
            emb_blob = text_to_embedding(chunk_text_val)
            cursor.execute(
                "INSERT INTO chunks (doc_id, chunk_index, page_num, content, embedding) VALUES (?, ?, ?, ?, ?)",
                (doc_id, idx, page, chunk_text_val, emb_blob)
            )
            total_chunks += 1

    # 2. Ingest real PDF files from documents/ folder
    pdf_files = glob.glob("documents/*.pdf")
    if pdf_files:
        print(f"Found {len(pdf_files)} PDF files in documents/ folder. Parsing with pdfplumber...")
        for pdf_path in pdf_files:
            fname = os.path.basename(pdf_path)
            fsize = os.path.getsize(pdf_path)
            fhash = f"hash_{hash(fname + str(fsize)) & 0xffffffff:08x}"
            
            try:
                parsed_chunks = []
                with pdfplumber.open(pdf_path) as pdf:
                    page_count = len(pdf.pages)
                    for page_idx, page in enumerate(pdf.pages):
                        extracted = page.extract_text()
                        if extracted:
                            pchunks = chunk_text(extracted)
                            for ch in pchunks:
                                parsed_chunks.append((page_idx + 1, ch))

                if parsed_chunks:
                    cursor.execute(
                        "INSERT INTO documents (filename, file_hash, file_type, page_count, chunk_count, date_added, file_size) VALUES (?, ?, ?, ?, ?, ?, ?)",
                        (fname, fhash, "pdf", page_count, len(parsed_chunks), "2026-09-10", fsize)
                    )
                    doc_id = cursor.lastrowid
                    total_docs += 1

                    for idx, (page_num, chunk_text_val) in enumerate(parsed_chunks):
                        emb_blob = text_to_embedding(chunk_text_val)
                        cursor.execute(
                            "INSERT INTO chunks (doc_id, chunk_index, page_num, content, embedding) VALUES (?, ?, ?, ?, ?)",
                            (doc_id, idx, page_num, chunk_text_val, emb_blob)
                        )
                        total_chunks += 1
                    print(f"  ✓ Ingested {fname}: {len(parsed_chunks)} chunks.")
                else:
                    print(f"  ⚠️ No readable text extracted from {fname}.")
            except Exception as e:
                print(f"  ✕ Error processing {fname}: {e}")

    conn.commit()
    conn.close()

    metadata = {
        "pack_id": "emergency_demo_v2",
        "name": "Emergency Full SOP Pack",
        "version": "2.0.0",
        "description": "Emergency first aid SOPs including WHO & Red Cross trauma manuals.",
        "created_at": "2026-09-10",
        "embedding_model": "all-MiniLM-L6-v2",
        "embedding_dim": 384,
        "doc_count": total_docs,
        "chunk_count": total_chunks,
        "disclaimer": "Demonstration dataset only. Not a substitute for professional medical advice."
    }

    with open("assets/sample/metadata.json", "w") as f:
        json.dump(metadata, f, indent=2)

    with zipfile.ZipFile(pack_path, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.write("assets/sample/metadata.json", arcname="metadata.json")
        zf.write(db_path, arcname="emergency_demo_knowledge.db")

    print(f"\n🎉 Successfully created {pack_path} with {total_docs} documents and {total_chunks} chunks!")

if __name__ == "__main__":
    main()