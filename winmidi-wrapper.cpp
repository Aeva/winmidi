#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <mmeapi.h>
#include <map>

#define DLL_EXPORT __declspec(dllexport)


struct MidiPacket
{
	BYTE Message = 0;
	BYTE Channel = 0;
	BYTE Data[2] = { 0 };
};


const int BUFFER_SIZE = 16;


struct InputConnection
{
	int Port;
	HMIDIIN Handle;
	bool Open = false;
	MidiPacket Buffer[BUFFER_SIZE] = { 0 };
	int Cursor = 0;
	int Live = 0;

	MidiPacket* Advance()
	{
		if (Live == BUFFER_SIZE)
		{
			--Live;
			Cursor = (Cursor + 1) % BUFFER_SIZE;
		}
		int Insert = (Cursor + Live++) % BUFFER_SIZE;
		return &Buffer[Insert];
	}

	MidiPacket Read()
	{
		if (Live > 0)
		{
			--Live;
		}
		int Next = Cursor;
		Cursor = (Cursor + 1) % BUFFER_SIZE;
		return Buffer[Next];
	}

	bool DataReady()
	{
		return Live > 0;
	}
};


std::map<int, InputConnection> LiveInputs;


static void CALLBACK MidiInProc(HMIDIIN hMidiIn, UINT wMsg, DWORD_PTR dwInstance, DWORD_PTR dwParam1, DWORD_PTR dwParam2)
{
	InputConnection* LiveInput = (InputConnection*)dwInstance;
	if (dwParam1 != 0)
	{
		const WORD LowWord = LOWORD(dwParam1);
		const WORD HighWord = HIWORD(dwParam1);
		const BYTE StatusByte = LOBYTE(LowWord);
		if (StatusByte)
		{
			MidiPacket* Packet = LiveInput->Advance();
			Packet->Message = StatusByte >> 4;
			Packet->Channel = StatusByte & 0xF;
			Packet->Data[0] = HIBYTE(LowWord);
			Packet->Data[1] = LOBYTE(HighWord);
		}
	}
}


extern "C"
{
	DLL_EXPORT void CloseInput(int Port)
	{
		InputConnection* LiveInput = &LiveInputs[Port];
		if (!LiveInput->Open)
		{
			return;
		}
		LiveInput->Open = false;
		midiInStop(LiveInput->Handle);
		midiInClose(LiveInput->Handle);
	}

	DLL_EXPORT MMRESULT OpenInput(int Port)
	{
		InputConnection* NewInput = &LiveInputs[Port];
		if (NewInput->Open)
		{
			CloseInput(Port);
		}

		MMRESULT Result = midiInOpen(&NewInput->Handle, Port, (DWORD_PTR)MidiInProc, (DWORD_PTR)NewInput, CALLBACK_FUNCTION);
		if (Result == MMSYSERR_NOERROR)
		{
			Result = midiInStart(NewInput->Handle);
		}

		if (Result == MMSYSERR_NOERROR)
		{
			NewInput->Open = true;
			NewInput->Port = Port;
			NewInput->Cursor = 0;
			NewInput->Live = 0;
		}

		return Result;
	}

	DLL_EXPORT bool PollInput(int Port, MidiPacket* OutPacket)
	{
		InputConnection* LiveInput = &LiveInputs[Port];
		if (LiveInput->Open && LiveInput->DataReady())
		{
			*OutPacket = LiveInput->Read();
			return true;
		}
		return false;
	}
}
